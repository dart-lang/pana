// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/utils.dart';
import 'package:path/path.dart' as path;
import 'package:pubspec_parse/pubspec_parse.dart' as p;

final maxFileSizeInBytes = 2097152; // 2MB
final maxFileSizeInMegaBytes = maxFileSizeInBytes / (1024 * 1024);
final maxNumberOfScreenshots = 5;

/// [ScreenshotResult] holds either a [ProcessedScreenshot] or a list of
/// problems describing what went wrong when trying to generate thumbnails and
/// screenshot.
class ScreenshotResult {
  // The temporary directory where the processed screenshots are stored.
  final String? _outDir;
  ProcessedScreenshot? processedScreenshot;
  List<String> problems;

  ScreenshotResult._(this.processedScreenshot, this.problems, this._outDir);

  factory ScreenshotResult.success(
      ProcessedScreenshot processedScreenshot, String outDir) {
    return ScreenshotResult._(processedScreenshot, [], outDir);
  }

  factory ScreenshotResult.failed(List<String> problems) {
    return ScreenshotResult._(null, problems, null);
  }

  /// The path to where the generated WebP thumbnail is temporarily stored.
  /// Should only be used if [processedScreenshot] is not null.
  String get webpThumbnailPath =>
      path.join(_outDir!, processedScreenshot!.webpThumbnail);

  /// The path to where the generated PNG thumbnail is temporarily stored.
  /// Should only be used if [processedScreenshot] is not null.
  String get pngThumbnailPath =>
      path.join(_outDir!, processedScreenshot!.pngThumbnail);

  /// The path to where the generated WebP screenshot is temporarily stored.
  /// Should only be used if [processedScreenshot] is not null.
  String get webpScreenshotPath =>
      path.join(_outDir!, processedScreenshot!.webpImage);
}

Future<List<ScreenshotResult>> processAllScreenshots(
    List<p.Screenshot> screenshots, String pkgDir) async {
  final results = <ScreenshotResult>[];
  final tempDir = Directory.systemTemp.createTempSync().path;
  var processedScreenshots = 0;
  for (final screenshot in screenshots) {
    final problems = <String>[];
    if (processedScreenshots == maxNumberOfScreenshots) {
      results.add(ScreenshotResult.failed(
        [
          '${screenshot.path}: Not processed. pub.dev shows at most $maxNumberOfScreenshots screenshots.'
        ],
      ));
      continue;
    }

    problems.addAll(_validateScreenshot(screenshot, pkgDir));
    if (problems.isNotEmpty) {
      results.add(ScreenshotResult.failed(problems));
      continue;
    }

    final result = await _processScreenshot(pkgDir, screenshot, tempDir);
    if (result.problems.isEmpty) {
      processedScreenshots++;
    }
    results.add(result);
  }
  return results;
}

List<String> _validateScreenshot(p.Screenshot screenshot, String pkgDir) {
  final problems = <String>[];
  if (screenshot.description.isEmpty) {
    problems.add(
        '${screenshot.path}: Screenshot `description` property is missing.');
  } else if (screenshot.description.length > 160) {
    problems.add(
        '${screenshot.path}: Screenshot `description` is too long. Description length must be less '
        'than 160 characters.');
  }
  if (screenshot.path.isEmpty) {
    problems.add('${screenshot.path}: Screenshot `path` property is missing.');
  }

  final fullPath = path.join(pkgDir, screenshot.path);
  if (!path.normalize(fullPath).startsWith(pkgDir)) {
    problems.add(
        '${screenshot.path}: Screenshot file path should be within the package.');
  }

  final origImage = File(fullPath);
  if (!origImage.existsSync()) {
    problems.add(
        '${screenshot.path}: No file found at specified screenshot `path` ${screenshot.path}');
  } else if (origImage.lengthSync() > maxFileSizeInBytes) {
    problems.add(
        '${screenshot.path}: Screenshot file size exceeds limit of $maxFileSizeInMegaBytes MB');
  }
  return problems;
}

Future<ScreenshotResult> _processScreenshot(
    String pkgDir, p.Screenshot e, String tempDir) async {
  final basename = path.basenameWithoutExtension(e.path);
  final webpName = '$basename.webp';
  final genDir = 'gen';
  final thumbnailDir = path.join(genDir, '100x100');
  final webpPath = path.join(genDir, webpName);
  final webpThumbnailPath = path.join(thumbnailDir, webpName);
  final pngName = '$basename.png';
  final pngThumbnailPath = path.join(thumbnailDir, pngName);
  final originalPath = path.join(pkgDir, e.path);

  Directory(path.join(tempDir, thumbnailDir)).createSync(recursive: true);

  final webpScreenshotProblems =
      await _generateWebpScreenshot(originalPath, path.join(tempDir, webpPath));
  if (webpScreenshotProblems.isNotEmpty) {
    return ScreenshotResult.failed(webpScreenshotProblems);
  }

  final thumbnailProblems = await _generateThumbnails(
      originalPath,
      path.join(tempDir, webpPath),
      path.join(tempDir, webpThumbnailPath),
      path.join(tempDir, pngThumbnailPath));
  if (thumbnailProblems.isNotEmpty) {
    return ScreenshotResult.failed(thumbnailProblems);
  }

  return ScreenshotResult.success(
      ProcessedScreenshot(e.path, e.description,
          webpImage: webpPath,
          webpThumbnail: webpThumbnailPath,
          pngThumbnail: pngThumbnailPath),
      tempDir);
}

/// Generates a WebP screenshot given the original image at [originalPath] and
/// writes it to [webpPath].
///
/// Returns a list of problems if generating the screenshot did not succeed.
/// On success, an empty list is returned.
///
/// The WebP screenshot can be either static or animated.
///
/// If the original image format is already WebP, the screenshot will simply be
/// copied over. The `webpinfo` tool is used for determining this.
/// Otherwise, a conversion is tried, using the `cwebp` tool which can handle
/// PNG, JPEG, and TIFF as input. For GIF files the `gif2webp` conversion tool
/// is used.
///
/// For any other input format the screenshot generation will fail. It will also
/// fail if any of the mentioned tools are not available on the command line and
/// an error message will be written to stderr.
Future<List<String>> _generateWebpScreenshot(
  String originalPath,
  String webpPath,
) async {
  final problems = <String>[];
  final copyIfWebpProblems = await _copyIfAlreadyWebp(originalPath, webpPath);
  if (copyIfWebpProblems.isEmpty) {
    return [];
  }
  problems.addAll(copyIfWebpProblems);

  final convertWithCwebpProblems =
      await _convertWithCWebp(originalPath, webpPath);
  if (convertWithCwebpProblems.isEmpty) {
    return [];
  }
  problems.addAll(convertWithCwebpProblems);

  final gif2webpProblems = await _convertGifToWebp(originalPath, webpPath);
  if (gif2webpProblems.isEmpty) {
    return [];
  }
  problems.addAll(gif2webpProblems);
  problems.add(
      'Generating webp image for $originalPath failed due to invalid input');
  return problems;
}

Future<List<String>> _copyIfAlreadyWebp(
    String originalPath, String webpPath) async {
  final infoResult = await _checkedRunProc(['webpinfo', originalPath]);
  if (infoResult.exitCode == 0) {
    await File(originalPath).copy(webpPath);
    return [];
  }
  return [
    '$originalPath: Tried interpreting screenshot as WebP. Failed with exitcode ${infoResult.exitCode}.'
  ];
}

Future<List<String>> _convertWithCWebp(
    String originalPath, String webpPath) async {
  final cwebpResult =
      await _checkedRunProc(['cwebp', originalPath, '-o', webpPath]);
  if (cwebpResult.exitCode == 0) {
    return [];
  }
  return [
    '$originalPath: Converting screenshot with `cwebp` failed with exitcode ${cwebpResult.exitCode}.'
  ];
}

Future<List<String>> _convertGifToWebp(
    String originalPath, String webpPath) async {
  final gif2webpResult =
      await _checkedRunProc(['gif2webp', originalPath, '-o', webpPath]);

  if (gif2webpResult.exitCode == 0) {
    return [];
  }
  return [
    '$originalPath: Tried interpreting screenshot as GIF. Failed with exitcode ${gif2webpResult.exitCode}.'
  ];
}

/// Generates a PNG and a WebP thumbnail from the WebP screenshot found at
/// [webpPath] and writes them to [pngThumbnailPath] and [webpThumbnailPath]
/// respectively.
///
/// Returns a list of problems if generating the thumbnails did not succeed.
/// On success, an empty list is returned.
//
/// If the WebP screenshot is animated, the `webpmux` tool is used to extract
/// the first frame for the thumbnail.
///
/// The `webpinfo` tool is used to determine the original height and width. The
/// `cwebp` converter is used for resizing the screenshot. The `dwebp` converter
/// is used for generating the thumbnail in PNG.
///
/// Thumbnail generation will fail if any of the mentioned tools are not
/// available on the command line and an error message will be written to stderr.
Future<List<String>> _generateThumbnails(String originalPath, String webpPath,
    String webpThumbnailPath, String pngThumbnailPath) async {
  late String staticWebpPath;
  final infoResult = await runProc(['webpinfo', webpPath]);
  if (infoResult.exitCode != 0) {
    return [
      "$originalPath: Running 'webpinfo' on $webpPath failed with exitcode ${infoResult.exitCode}."
    ];
  }

  if ((infoResult.stdout as String).contains('Animation: 1')) {
    staticWebpPath = path.join(Directory.systemTemp.path,
        '${path.basenameWithoutExtension(webpPath)}_static.webp');
    // input file is animated, extract the first frame.
    final webpmuxResult = await _checkedRunProc(
        ['webpmux', '-get', 'frame', '1', webpPath, '-o', staticWebpPath]);

    if (webpmuxResult.exitCode != 0) {
      return [
        "$originalPath: Extracting frame from $webpPath with 'webpmux' failed with exitcode ${webpmuxResult.exitCode}"
      ];
    }
  } else {
    staticWebpPath = webpPath;
  }

  final stdout = infoResult.stdout as String;
  final lines = stdout.split('\n');
  final widthString =
      lines.firstWhere((String line) => line.contains('Width:'));
  final heightString =
      lines.firstWhere((String line) => line.contains('Height:'));
  final width = int.parse(widthString.split(':').last.trim());
  final height = int.parse(heightString.split(':').last.trim());

  final int widthArgument;
  final int heightArgument;
  if (width > height) {
    widthArgument = 100;
    heightArgument = 0;
  } else {
    widthArgument = 0;
    heightArgument = 100;
  }
  final resizeResult = await runProc([
    'cwebp',
    '-resize',
    '$widthArgument',
    '$heightArgument',
    staticWebpPath,
    '-o',
    webpThumbnailPath
  ]);
  if (resizeResult.exitCode != 0) {
    return [
      "$originalPath: Resizing to WebP thumbnail with 'cwebp -resize' failed with exitcode ${resizeResult.exitCode}"
    ];
  }

  final pngResult = await _checkedRunProc(
      ['dwebp', webpThumbnailPath, '-o', pngThumbnailPath]);
  if (pngResult.exitCode != 0) {
    return [
      "$originalPath: Generating PNG thumbnail with 'webp' failed with exitcode ${pngResult.exitCode}"
    ];
  }
  return [];
}

Future<PanaProcessResult> _checkedRunProc(List<String> cmdAndArgs) async {
  final result = await runProc(cmdAndArgs);
  if (result.exitCode == 127) {
    stderr.write("'${cmdAndArgs[0]}' tool not found.");
  }
  return result;
}
