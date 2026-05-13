// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:pubspec_parse/pubspec_parse.dart' as p;

import '../pana.dart';
import 'tool/web_tool.dart';

final _maxFileSizeInMegaBytes = 4;
final _maxFileSizeInBytes = _maxFileSizeInMegaBytes * (1024 * 1024);
final _maxNumberOfScreenshots = 10;

/// [ScreenshotResult] holds either a [ProcessedScreenshot] or a list of
/// problems describing what went wrong when trying to generate thumbnails and
/// screenshot.
class ScreenshotResult {
  ProcessedScreenshot? processedScreenshot;
  Uint8List? webpImageBytes;
  Uint8List? webp100ThumbnailBytes;
  Uint8List? png100ThumbnailBytes;
  Uint8List? webp190ThumbnailBytes;
  Uint8List? png190ThumbnailBytes;
  List<String> problems;

  ScreenshotResult._(
    this.processedScreenshot,
    this.webpImageBytes,
    this.webp100ThumbnailBytes,
    this.png100ThumbnailBytes,
    this.webp190ThumbnailBytes,
    this.png190ThumbnailBytes,
    this.problems,
  );

  factory ScreenshotResult.success(
    ProcessedScreenshot processedScreenshot,
    Uint8List webpImageBytes,
    Uint8List webp100ThumbnailBytes,
    Uint8List png100ThumbnailBytes,
    Uint8List webp190ThumbnailBytes,
    Uint8List png190ThumbnailBytes,
  ) {
    return ScreenshotResult._(
      processedScreenshot,
      webpImageBytes,
      webp100ThumbnailBytes,
      png100ThumbnailBytes,
      webp190ThumbnailBytes,
      png190ThumbnailBytes,
      [],
    );
  }

  factory ScreenshotResult.failed(List<String> problems) {
    return ScreenshotResult._(null, null, null, null, null, null, problems);
  }
}

Future<List<ScreenshotResult>> processAllScreenshots(
  List<p.Screenshot> screenshots,
  String pkgDir,
  WebpTool webpTool,
) async {
  final tempDir = Directory.systemTemp.createTempSync();
  try {
    final results = <ScreenshotResult>[];
    var processedScreenshots = 0;
    for (final screenshot in screenshots) {
      final problems = <String>[];
      if (processedScreenshots == _maxNumberOfScreenshots) {
        results.add(
          ScreenshotResult.failed([
            '${screenshot.path}: Not processed. pub.dev shows at most $_maxNumberOfScreenshots screenshots.',
          ]),
        );
        continue;
      }

      problems.addAll(_validateScreenshot(screenshot, pkgDir));
      if (problems.isNotEmpty) {
        results.add(ScreenshotResult.failed(problems));
        continue;
      }

      final result = await _processScreenshot(
        webpTool,
        pkgDir,
        screenshot,
        tempDir.path,
      );
      if (result.problems.isEmpty) {
        processedScreenshots++;
      }
      results.add(result);
    }
    return results;
  } finally {
    tempDir.deleteSync(recursive: true);
  }
}

List<String> _validateScreenshot(p.Screenshot screenshot, String pkgDir) {
  final problems = <String>[];
  if (screenshot.description.isEmpty) {
    problems.add(
      '${screenshot.path}: Screenshot `description` property is missing.',
    );
  } else if (screenshot.description.length > 160) {
    problems.add(
      '${screenshot.path}: Screenshot `description` is too long. Description length must be less '
      'than 160 characters.',
    );
  }
  if (screenshot.path.isEmpty) {
    problems.add('${screenshot.path}: Screenshot `path` property is missing.');
  }

  final fullPath = path.join(pkgDir, screenshot.path);
  if (!path.isWithin(pkgDir, fullPath)) {
    problems.add(
      '${screenshot.path}: Screenshot file path should be within the package.',
    );
  }

  final origImage = File(fullPath);
  if (!origImage.existsSync()) {
    problems.add(
      '${screenshot.path}: No file found at specified screenshot `path` ${screenshot.path}',
    );
  } else if (origImage.lengthSync() > _maxFileSizeInBytes) {
    problems.add(
      '${screenshot.path}: Screenshot file size exceeds limit of $_maxFileSizeInMegaBytes MB',
    );
  }
  return problems;
}

Future<ScreenshotResult> _processScreenshot(
  WebpTool webpTool,
  String pkgDir,
  p.Screenshot e,
  String tempDir,
) async {
  final nameWithNoExt = path.withoutExtension(e.path);
  final webpName = '$nameWithNoExt.webp';
  final pngName = '$nameWithNoExt.png';

  final genDir = 'gen';
  final thumbnail100Dir = path.join(genDir, '100x100');
  final thumbnail190Dir = path.join(genDir, '190x190');
  final webpPath = path.join(genDir, webpName);
  final webp100ThumbnailPath = path.join(thumbnail100Dir, webpName);
  final webp190ThumbnailPath = path.join(thumbnail190Dir, webpName);
  final png100ThumbnailPath = path.join(thumbnail100Dir, pngName);
  final png190ThumbnailPath = path.join(thumbnail190Dir, pngName);
  final originalPath = path.join(pkgDir, e.path);

  Directory(
    path.join(tempDir, path.dirname(webpPath)),
  ).createSync(recursive: true);
  Directory(
    path.join(tempDir, path.dirname(webp100ThumbnailPath)),
  ).createSync(recursive: true);
  Directory(
    path.join(tempDir, path.dirname(webp190ThumbnailPath)),
  ).createSync(recursive: true);

  final webpScreenshotProblems = await webpTool.convertToWebp(
    originalPath,
    path.join(tempDir, webpPath),
  );
  if (webpScreenshotProblems.isNotEmpty) {
    return ScreenshotResult.failed(webpScreenshotProblems);
  }

  final thumbnailProblems = await webpTool.generateThumbnails(
    originalPath,
    path.join(tempDir, webpPath),
    path.join(tempDir, webp100ThumbnailPath),
    path.join(tempDir, png100ThumbnailPath),
    path.join(tempDir, webp190ThumbnailPath),
    path.join(tempDir, png190ThumbnailPath),
    tempDir,
  );
  if (thumbnailProblems.isNotEmpty) {
    return ScreenshotResult.failed(thumbnailProblems);
  }

  return ScreenshotResult.success(
    ProcessedScreenshot(
      e.path,
      e.description,
      webpImage: webpPath,
      webp100Thumbnail: webp100ThumbnailPath,
      png100Thumbnail: png100ThumbnailPath,
      webp190Thumbnail: webp190ThumbnailPath,
      png190Thumbnail: png190ThumbnailPath,
    ),
    File(path.join(tempDir, webpPath)).readAsBytesSync(),
    File(path.join(tempDir, webp100ThumbnailPath)).readAsBytesSync(),
    File(path.join(tempDir, png100ThumbnailPath)).readAsBytesSync(),
    File(path.join(tempDir, webp190ThumbnailPath)).readAsBytesSync(),
    File(path.join(tempDir, png190ThumbnailPath)).readAsBytesSync(),
  );
}
