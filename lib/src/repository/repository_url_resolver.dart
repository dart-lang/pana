// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

import '../model.dart';

final _imageExtensions = <String>{'.gif', '.jpg', '.jpeg', '.png'};

extension RepositoryUrlResolverExt on Repository {
  /// Resolves a reference in relationship with the repository, and returns:
  /// - the same URL if the [reference] is absolute,
  /// - the same URL if the [reference] is in-page anchor,
  /// - a new URL if the [reference] is relative and valid
  ///
  /// If [branch] is specified, it will override the [Repository]'s default branch.
  ///
  /// When present, [relativeFrom] specifies the file that is being rendered,
  /// and relative [reference] will be resolved from that location.
  ///
  /// When [reference] is used inside `<img>` or similar tag,
  /// [isEmbeddedObject] should be set to `true`. On compatible
  /// providers the resolved URL will use the raw reference to content.
  String? tryResolveUrl(
    String reference, {
    String? branch,
    String? relativeFrom,
    bool? isEmbeddedObject,
  }) {
    isEmbeddedObject ??= false;
    final parsedReference = Uri.tryParse(reference);
    if (parsedReference == null) {
      return null;
    }
    try {
      // trigger exception if there is an issue
      parsedReference.pathSegments;
      parsedReference.queryParameters;
    } on FormatException {
      return null;
    }
    if (parsedReference.hasScheme || parsedReference.path.isEmpty) {
      return reference;
    }
    var referenceIsAbsolute = false;
    var referencePath = p.normalize(parsedReference.path);
    while (referencePath.startsWith('/')) {
      referencePath = referencePath.substring(1);
      referenceIsAbsolute = true;
    }
    if (relativeFrom != null && !referenceIsAbsolute) {
      referencePath = p.normalize(p.joinAll([
        p.dirname(relativeFrom),
        referencePath,
      ]));
      while (referencePath.startsWith('/')) {
        referencePath = referencePath.substring(1);
      }
    }

    late String finalPath;

    // GitHub resolves references only inside the repository.
    if (RepositoryProvider.isGitHubCompatible(provider)) {
      final extension = p.extension(reference).toLowerCase();
      final needsRaw = isEmbeddedObject || _imageExtensions.contains(extension);
      final separator = (needsRaw ? 'raw' : null) ?? 'blob';

      final normalizedPath = referenceIsAbsolute
          ? referencePath
          : p.normalize(p.joinAll([
              if (path != null) path!,
              referencePath,
            ]));
      final parts = p.split(normalizedPath);
      final sanitizedPath = parts.contains('..')
          ? p.joinAll(parts.sublist(parts.lastIndexOf('..') + 1))
          : normalizedPath;

      finalPath = p.normalize(p.joinAll([
        repository,
        separator,
        branch ?? this.branch ?? 'master',
        sanitizedPath
      ].whereType<String>()));
    } else {
      // For unknown providers resolution follows normal URL rules.
      finalPath = referenceIsAbsolute
          ? referencePath
          : p.normalize(p.joinAll([
              repository,
              if (path != null) path!,
              referencePath,
            ].whereType<String>()));
    }

    final queryParametersAll =
        parsedReference.hasQuery && parsedReference.queryParameters.isNotEmpty
            ? parsedReference.queryParametersAll
            : null;
    final fragment = parsedReference.hasFragment &&
            parsedReference.fragment.trim().isNotEmpty
        ? parsedReference.fragment.trim()
        : null;
    return Uri(
      scheme: 'https',
      host: host,
      path: finalPath,
      queryParameters: queryParametersAll,
      fragment: fragment,
    ).toString();
  }

  /// Resolves a reference in relationship with the repository, and returns:
  /// - the same URL if the [reference] is absolute,
  /// - the same URL if the [reference] is in-page anchor,
  /// - a new URL if the [reference] is relative and valid
  ///
  /// Throws [FormatException] when the [reference] is invalid in the scope of the repository.
  ///
  /// If [branch] is specified, it will override the [Repository]'s default branch.
  ///
  /// When present, [relativeFrom] specifies the file that is being rendered,
  /// and relative [reference] will be resolved from that location.
  ///
  /// When [reference] is used inside `<img>` or similar tag,
  /// [isEmbeddedObject] should be set to `true`. On compatible
  /// providers the resolved URL will use the raw reference to content.
  String resolveUrl(
    String reference, {
    String? branch,
    String? relativeFrom,
    bool? isEmbeddedObject,
  }) {
    final v = tryResolveUrl(
      reference,
      branch: branch,
      relativeFrom: relativeFrom,
      isEmbeddedObject: isEmbeddedObject,
    );
    if (v == null) {
      throw FormatException('Unable to resolve reference: `$reference`.');
    }
    return v;
  }
}
