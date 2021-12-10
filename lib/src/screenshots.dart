// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:pana/pana.dart';
import 'package:pana/src/package_context.dart';
import 'package:path/path.dart' as path;
import 'package:pubspec_parse/pubspec_parse.dart' as p;

Map<String, List<String>>? _screenshotValidationProblems;

Map<String, List<String>> validateScreenshots(
    List<p.Screenshot> screenshots, String pkgDir) {
  if (_screenshotValidationProblems != null) {
    return _screenshotValidationProblems!;
  }

  final problems = <String, List<String>>{};
  for (final e in screenshots) {
    if (e.description.isEmpty) {
      problems
          .putIfAbsent(e.path, () => [])
          .add('Screenshot description missing');
    } else if (e.description.length > 160) {
      problems.putIfAbsent(e.path, () => []).add(
          'Screenshot description too long. Description length must be less '
          'than 160 characters.');
    }

    final origImage = File(path.join(pkgDir, e.path));
    if (!origImage.existsSync()) {
      problems
          .putIfAbsent(e.path, () => [])
          .add('No screenshot found at speficifed path ${e.path}');
    }
  }
  _screenshotValidationProblems = problems;
  return _screenshotValidationProblems!;
}

Future<List<ProcessedScreenshot>> generateScreenshots(
    PackageContext context, List<p.Screenshot> screenshots) async {
  final processed = <ProcessedScreenshot>[];
  for (final e in screenshots) {
    final basename = path.basenameWithoutExtension(e.path);
    final dirname = path.dirname(e.path);
    final webpName = '$basename.webp';
    final genDir = 'gen';
    final thumbnailDir = path.join(genDir, '100x100');
    final webpPath = path.join(dirname, genDir, webpName);
    final webpThumbnailPath = path.join(dirname, thumbnailDir, webpName);
    final pngName = '$basename.png';
    final pngThumbnailPath = path.join(dirname, thumbnailDir, pngName);

    Directory(thumbnailDir).createSync(recursive: true);

    if (!(await _generateStaticWebpImage(context, e.path, webpPath))) {
      continue;
    }

    // Generate webp thumbnail
    final resizeResult = await runProc(
        ['cwebp', '-resize', '100', '0', webpPath, '-o', webpThumbnailPath]);
    if (resizeResult.exitCode != 0) {
      continue;
    }

    // Generate png thumbnail
    final pngResult =
        await runProc(['dwebp', webpThumbnailPath, '-o', pngThumbnailPath]);
    if (pngResult.exitCode != 0) {
      continue;
    }

    processed.add(ProcessedScreenshot(e.path, e.description,
        webpImage: webpPath,
        webpThumbnail: webpThumbnailPath,
        pngThumbnail: pngThumbnailPath));
  }

  return processed;
}

Future<bool> _generateStaticWebpImage(
  PackageContext context,
  String originalPath,
  String webpPath,
) async {
  final errors = <String>[];

  final webpExitCode = await generateFromWebp(originalPath, webpPath);
  if (webpExitCode == 0) {
    return true;
  }
  if (webpExitCode == 127) {
    errors.add('Generating from webp failed due to missing tool');
  }

  final cwebpExitCode = await convertWithCWebp(originalPath, webpPath);
  if (cwebpExitCode == 0) {
    return true;
  }
  if (cwebpExitCode == 127) {
    errors.add("Converting to webp failed due to missing 'cwebp' tool");
  }

  final gifToWebpExitCode = await convertGifToWebp(originalPath, webpPath);
  if (gifToWebpExitCode == 0) {
    return true;
  }
  if (gifToWebpExitCode == 127) {
    errors.add(
        "Converting from gif to webp failed due to missing 'gif2webp' tool");
  }

  errors.add(
      'generating webp image for $originalPath failed due to invalid input '
      'or missing tools.');

  context.errors.addAll(errors);

  return false;
}

Future<int> generateFromWebp(String originalPath, String webpPath) async {
  final infoResult = await runProc(
    ['webpinfo', originalPath],
  );
  if (infoResult.exitCode != 0) {
    // webpinfo tool is not available or the input is not a valid webp file.
    return infoResult.exitCode;
  }

  if ((infoResult.stdout as String).contains('Animation: 1')) {
    // input file is animated, extract the first frame.
    final webpmuxResult = await runProc(
        ['webpmux', '-get frame 0', originalPath, '-o', webpPath]);

    return webpmuxResult.exitCode;
  }

  // original image is a non-animated webp image
  await File(originalPath).copy(webpPath);
  return 0;
}

Future<int> convertWithCWebp(String originalPath, String webpPath) async {
  final cwebpResult = await runProc(
    ['cwebp', originalPath, '-o', webpPath],
  );
  return cwebpResult.exitCode;
}

Future<int> convertGifToWebp(String originalPath, String webpPath) async {
  final animatedWebpPath = path.join(Directory.systemTemp.path,
      '${path.basenameWithoutExtension(webpPath)}_ani.webp');
  final gif2webpResult = await runProc(
    ['gif2webp', originalPath, '-o', animatedWebpPath],
  );

  if (gif2webpResult.exitCode != 0) {
    return gif2webpResult.exitCode;
  }

  final webpmuxResult = await runProc(
      ['webpmux', '-get frame 0', originalPath, '-o', animatedWebpPath]);
  return webpmuxResult.exitCode;
}
