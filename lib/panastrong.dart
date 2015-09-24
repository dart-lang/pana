import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'io.dart';
import 'logging.dart';
import 'src/analyzer_output.dart';
import 'src/summary.dart';

export 'src/analyzer_output.dart';
export 'src/summary.dart';

final _summaryPattern = new RegExp(r"^No issues found|\d+.*?found\.$");

final _firstLinePattern = new RegExp(r'Analyzing \[.*?\]\.\.\.');

Future<Summary> run(String packageName) async {
  log.info('Starting package "$packageName".');

  var tempDir =
      await Directory.systemTemp.createTemp('panastrong.$packageName.');

  try {
    var client = new IOClient();

    Map<String, dynamic> packageDetails;
    DateTime downloadDate;

    try {
      var info = await getPackageInfo(packageName, client);

      packageDetails = info['latest'];

      var version = packageDetails['version'];
      log.info('Version $version');

      var archiveUri = Uri.parse(packageDetails['archive_url']);

      downloadDate = await downloadAndExtract(tempDir.path, archiveUri, client);
    } finally {
      client.close();
    }

    // run pub get
    var result =
        await Process.run('pub', ['upgrade'], workingDirectory: tempDir.path);
    if (result.exitCode != 0) {
      throw new ProcessException(
          'pub', ['upgrade'], result.stderr, result.exitCode);
    }

    var items = await analyze(tempDir.path, strong: true);

    return new Summary(packageName, packageDetails, downloadDate, items);
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

Future<Map> getPackageInfo(String packageName, Client client) async {
  var pkgUri = 'https://pub.dartlang.org/api/packages/$packageName';
  log.info('Downloading $pkgUri');

  var response = await client.read(pkgUri);

  return JSON.decode(response);
}

Future<DateTime> downloadAndExtract(
    String tempDir, Uri archiveUri, Client client) async {
  log.info('Downloading $archiveUri');
  assert(archiveUri.toString().endsWith('.tar.gz'));

  var streamedResponse = await client.send(new Request('GET', archiveUri));

  if (streamedResponse.statusCode != 200) {
    // TODO: provide more info here
    throw new HttpException(
        "Failed with status code ${streamedResponse.statusCode}",
        uri: archiveUri);
  }

  log.info('Extracting to $tempDir');
  await extractTarGz(streamedResponse.stream, tempDir);
  log.info('Extracted to $tempDir');

  var dateHeader = streamedResponse.headers['date'];
  DateTime date;
  if (dateHeader != null) {
    date = parseHttpDate(dateHeader);
  }

  return date;
}

Future<Map<String, List<AnalyzerOutput>>> analyze(String projectDir,
    {bool strong}) async {
  // find all dart files in 'lib' directory
  var dir = new Directory(projectDir).absolute;
  projectDir = dir.path;

  var libsRelativePaths = await getLibraries(projectDir);

  var args = <String>[];

  if (strong == true) {
    args.add('--strong');
  }

  args.addAll(libsRelativePaths);

  var process =
      await Process.start('dartanalyzer', args, workingDirectory: projectDir);

  var items = new Map<String, List<AnalyzerOutput>>.fromIterable(
      libsRelativePaths,
      value: (_) => <AnalyzerOutput>[]);

  var errDrain = getLines(process.stderr).forEach((line) {
    log.warning('Analyzer stderr: $line');
  });

  try {
    var currentLibIndex = 0;
    String currentFile = libsRelativePaths[currentLibIndex];

    var buffer = new StringBuffer();

    var firstLine = true;

    await for (var line in getLines(process.stdout)) {
      if (firstLine) {
        if (_firstLinePattern.hasMatch(line)) {
          firstLine = false;
        } else {
          log.warning('Weird:\t$line');
        }

        continue;
      }

      if (_summaryPattern.hasMatch(line)) {
        if (buffer.isNotEmpty) {
          print(items);
          throw "weird!\n$buffer";
        }

        log.info('Done with $currentFile\n$line');
        ++currentLibIndex;
        if (currentLibIndex >= libsRelativePaths.length) {
          currentFile = null;
        } else {
          currentFile = libsRelativePaths[currentLibIndex];
        }
        continue;
      }

      buffer.writeln(line);

      var issue = AnalyzerOutput.parseOrNull(buffer.toString());
      if (issue != null) {
        buffer.clear();
        items[currentFile].add(issue);
      }
    }
  } finally {
    await errDrain;
  }

  var code = await process.exitCode;

  if (code != 0 && code != 3) {
    throw "Analyzer failed with exit code $code";
  }

  return items;
}

Future<List<String>> getLibraries(String projectDir) async {
  var libDir = new Directory(p.join(projectDir, 'lib'));

  var libFiles = await libDir
      .list(recursive: false, followLinks: false)
      .where((fse) =>
          fse is File && p.extension(fse.path.toLowerCase()) == '.dart')
      .map((fse) => p.relative(fse.path, from: projectDir))
      .toList();

  return libFiles;
}
