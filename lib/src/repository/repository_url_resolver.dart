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
  /// When [reference] is used inside `<img>` or similar tag,
  /// [isEmbeddedObject] should be set to `true`. On compatible
  /// providers the resolved URL will use the raw reference to content.
  String? tryResolveUrl(
    String reference, {
    String? branch,
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
    if (parsedReference.isAbsolute || parsedReference.path.isEmpty) {
      return reference;
    }
    final newPath = p.joinAll([
      if (path != null) path!,
      parsedReference.path,
    ]);
    final normalizedNewPath = p.normalize(newPath);
    String? separator;

    if (RepositoryProvider.isGitHubCompatible(provider)) {
      final extension = p.extension(reference).toLowerCase();
      final needsRaw = isEmbeddedObject || _imageExtensions.contains(extension);
      separator = (needsRaw ? 'raw' : null) ?? 'blob';
    }
    final newEnding = p.normalize(p.joinAll([
      repository,
      separator,
      branch ?? this.branch ?? 'master',
      normalizedNewPath
    ].whereType<String>()));

    return Uri(
      scheme: 'https',
      host: host,
      path: newEnding,
      fragment: parsedReference.hasFragment ? parsedReference.fragment : null,
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
  /// When [reference] is used inside `<img>` or similar tag,
  /// [isEmbeddedObject] should be set to `true`. On compatible
  /// providers the resolved URL will use the raw reference to content.
  String resolveUrl(
    String reference, {
    String? branch,
    bool? isEmbeddedObject,
  }) {
    final v = tryResolveUrl(
      reference,
      branch: branch,
      isEmbeddedObject: isEmbeddedObject,
    );
    if (v == null) {
      throw FormatException('Unable to resolve reference: `$reference`.');
    }
    return v;
  }
}
