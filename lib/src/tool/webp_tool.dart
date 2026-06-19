// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../logging.dart';
import '../sandbox_runner.dart';
import 'run_constrained.dart';

/// A tool for processing images using WebP-related command-line tools.
///
/// This class wraps the execution of image processing tools (`webpinfo`, `cwebp`,
/// `dwebp`, `gif2webp`, `webpmux`) through a [SandboxRunner] for secure execution.
class WebpTool {
  final SandboxRunner _sandboxRunner;

  WebpTool(this._sandboxRunner);

  /// writes it to [targetWebpPath].
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
  Future<List<String>> convertToWebp(
    String originalPath,
    String targetWebpPath,
  ) async {
    final problems = <String>[];
    final copyIfWebpProblems = await _copyIfAlreadyWebp(
      originalPath,
      targetWebpPath,
    );
    if (copyIfWebpProblems.isEmpty) {
      return [];
    }
    problems.addAll(copyIfWebpProblems);

    final convertWithCwebpProblems = await _convertWithCwebp(
      originalPath,
      targetWebpPath,
    );
    if (convertWithCwebpProblems.isEmpty) {
      return [];
    }
    problems.addAll(convertWithCwebpProblems);

    final gif2webpProblems = await _convertGifToWebp(
      originalPath,
      targetWebpPath,
    );
    if (gif2webpProblems.isEmpty) {
      return [];
    }
    problems.addAll(gif2webpProblems);
    problems.add(
      'Generating webp image for $originalPath failed due to invalid input',
    );
    return problems;
  }

  Future<List<String>> _copyIfAlreadyWebp(
    String originalPath,
    String webpPath,
  ) async {
    return await _checkedRunProc(
      ['webpinfo', originalPath],
      failureText:
          '`$originalPath`: Tried interpreting screenshot as WebP with `webpinfo "$originalPath"`',
      onSuccess: (_) async {
        await File(originalPath).copy(webpPath);
      },
      inputFilePath: originalPath,
      outputFilePath: null,
    );
  }

  Future<List<String>> _convertWithCwebp(
    String originalPath,
    String webpPath,
  ) async {
    return await _checkedRunProc(
      ['cwebp', originalPath, '-o', webpPath],
      failureText:
          '`$originalPath`: Converting screenshot with `cwebp "$originalPath" -o "$webpPath"`',
      inputFilePath: originalPath,
      outputFilePath: webpPath,
    );
  }

  Future<List<String>> _convertGifToWebp(
    String originalPath,
    String webpPath,
  ) async {
    return await _checkedRunProc(
      ['gif2webp', originalPath, '-o', webpPath],
      failureText:
          '`$originalPath`: Tried interpreting screenshot as GIF with `gif2webp "$originalPath" -o "$webpPath"`',
      inputFilePath: originalPath,
      outputFilePath: webpPath,
    );
  }

  /// Generates PNG and a WebP thumbnails from the WebP screenshot found at
  /// [webpPath] and writes them to [png100ThumbnailPath], [webp100ThumbnailPath]
  /// [png190ThumbnailPath], and [webp190ThumbnailPath] respectively.
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
  Future<List<String>> generateThumbnails(
    String originalPath,
    String webpPath,
    String webp100ThumbnailPath,
    String png100ThumbnailPath,
    String webp190ThumbnailPath,
    String png190ThumbnailPath,
    String tempDir,
  ) async {
    late String staticWebpPath;
    late String infoOutput;
    final infoResult = await _checkedRunProc(
      ['webpinfo', webpPath],
      onSuccess: (infoResult) {
        infoOutput = infoResult.stdout.asString;
      },
      failureText: '`$originalPath`: Running `webpinfo "$webpPath"`',
      inputFilePath: webpPath,
      outputFilePath: null,
    );
    if (infoResult.isNotEmpty) {
      return infoResult;
    }

    if (infoOutput.contains('Animation: 1')) {
      staticWebpPath = path.join(
        tempDir,
        '${path.basenameWithoutExtension(webpPath)}_static.webp',
      );
      // input file is animated, extract the first frame.
      final webpmuxResult = await _checkedRunProc(
        ['webpmux', '-get', 'frame', '1', webpPath, '-o', staticWebpPath],
        failureText:
            '`$originalPath`: Extracting frame from $webpPath with `webpmux -get frame 1 "$webpPath" -o "$staticWebpPath"`',
        inputFilePath: webpPath,
        outputFilePath: staticWebpPath,
      );

      if (webpmuxResult.isNotEmpty) {
        return webpmuxResult;
      }
    } else {
      staticWebpPath = webpPath;
    }

    final lines = infoOutput.split('\n');
    final widthString = lines.firstWhere(
      (String line) => line.contains('Width:'),
    );
    final heightString = lines.firstWhere(
      (String line) => line.contains('Height:'),
    );
    final width = int.parse(widthString.split(':').last.trim());
    final height = int.parse(heightString.split(':').last.trim());

    Future<List<String>> resizeWebp(
      String originalPath,
      int originalWidth,
      int originalHeight,
      int outputSize,
      String outputPath,
    ) async {
      final int widthArgument;
      final int heightArgument;

      if (originalWidth > originalHeight) {
        widthArgument = outputSize;
        heightArgument = 0;
      } else {
        widthArgument = 0;
        heightArgument = outputSize;
      }

      return await _checkedRunProc(
        [
          'cwebp',
          '-resize',
          '$widthArgument',
          '$heightArgument',
          originalPath,
          '-o',
          outputPath,
        ],
        failureText:
            '`$originalPath`: Resizing to WebP thumbnail with `cwebp -resize $widthArgument $heightArgument "$staticWebpPath" -o "$outputPath"`',
        inputFilePath: originalPath,
        outputFilePath: outputPath,
      );
    }

    final resizeWebp100Result = await resizeWebp(
      staticWebpPath,
      width,
      height,
      100,
      webp100ThumbnailPath,
    );
    if (resizeWebp100Result.isNotEmpty) {
      return resizeWebp100Result;
    }
    final resizeWebp190Result = await resizeWebp(
      staticWebpPath,
      width,
      height,
      190,
      webp190ThumbnailPath,
    );
    if (resizeWebp190Result.isNotEmpty) {
      return resizeWebp190Result;
    }

    final png100Result = await _checkedRunProc(
      ['dwebp', webp100ThumbnailPath, '-o', png100ThumbnailPath],
      failureText:
          '`$originalPath`: Generating PNG thumbnail with `dwebp "$webp100ThumbnailPath" -o "$png100ThumbnailPath"`',
      inputFilePath: webp100ThumbnailPath,
      outputFilePath: png100ThumbnailPath,
    );
    if (png100Result.isNotEmpty) {
      return png100Result;
    }

    final png190Result = await _checkedRunProc(
      ['dwebp', webp190ThumbnailPath, '-o', png190ThumbnailPath],
      failureText:
          '`$originalPath`: Generating PNG thumbnail with `dwebp "$webp190ThumbnailPath" -o "$png190ThumbnailPath"`',
      inputFilePath: webp190ThumbnailPath,
      outputFilePath: png190ThumbnailPath,
    );
    if (png190Result.isNotEmpty) {
      return png190Result;
    }

    return [];
  }

  Future<List<String>> _checkedRunProc(
    List<String> cmdAndArgs, {
    FutureOr<void> Function(PanaProcessResult pr)? onSuccess,
    required String inputFilePath,
    required String? outputFilePath,
    required String failureText,
  }) async {
    try {
      final inputDirPath = path.dirname(inputFilePath);
      final outputDirPath = outputFilePath == null
          ? null
          : path.dirname(outputFilePath);

      // Convert absolute paths in command arguments to be relative to the working directory
      final relativeCmdAndArgs = cmdAndArgs.map((arg) {
        // Skip the command name (first argument) and flags
        if (arg == cmdAndArgs.first || arg.startsWith('-')) {
          return arg;
        }
        // Convert file paths to be relative to the working directory
        if (path.isAbsolute(arg) || arg.contains(path.separator)) {
          return path.relative(arg, from: inputDirPath);
        }
        return arg;
      }).toList();

      final pr = await _sandboxRunner.runSandboxed(
        relativeCmdAndArgs,
        workingDirectory: inputDirPath,
        outputFolder: outputDirPath,
      );
      if (pr.exitCode == 0) {
        if (onSuccess != null) {
          await onSuccess(pr);
        }
        return [];
      } else {
        return ['$failureText failed with _exit code_ ${pr.exitCode}.'];
      }
    } on ProcessException catch (e) {
      log.severe("'${cmdAndArgs[0]}' tool not found.");
      final message = e.message.isEmpty
          ? "'${cmdAndArgs[0]}' tool not found."
          : e.message;
      return [message];
    }
  }
}
