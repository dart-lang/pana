import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as p;

import 'src/analyzer_output.dart';
import 'src/io.dart';
import 'src/logging.dart';
import 'src/summary.dart';

export 'src/analyzer_output.dart';
export 'src/summary.dart';

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

    log.info('Running pub upgrade');
    var result =
        await Process.run('pub', ['upgrade'], workingDirectory: tempDir.path);
    if (result.exitCode != 0) {
      throw new ProcessException(
          'pub', ['upgrade'], result.stderr, result.exitCode);
    }
    log.info('Finished pub upgrade');

    log.info('Starting analysis');
    var items = await analyze(tempDir.path, strong: true);
    log.info('Finished analysis');

    return new Summary(packageName, packageDetails, downloadDate,
        new List<AnalyzerOutput>.unmodifiable(items));
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

Future<List<AnalyzerOutput>> analyze(String projectDir, {bool strong}) async {
  // find all dart files in 'lib' directory
  projectDir = new Directory(projectDir).resolveSymbolicLinksSync();

  var libsRelativePaths = await getLibraries(projectDir);

  var args = <String>['--format', 'machine'];

  if (strong == true) {
    args.add('--strong');
  }

  args.addAll(libsRelativePaths);

  var process =
      await Process.start('dartanalyzer', args, workingDirectory: projectDir);

  var stdoutDrain = getLines(process.stdout).forEach((line) {
    log.warning('Analyzer stdout: $line');
  });

  List<AnalyzerOutput> items;
  try {
    items = await getLines(process.stderr)
        .map((line) => AnalyzerOutput.parse(line, projectDir: projectDir))
        .toList();
  } finally {
    await stdoutDrain;
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
