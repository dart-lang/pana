// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:collection/collection.dart';

import 'dartdoc_index.dart';
import 'pub_dartdoc_data.dart';

const _commonApiSymbols = <String>{
  'toString',
  'noSuchMethod',
  'hashCode',
  'runtimeType',
};

PubDartdocData dataFromDartdocIndex(DartdocIndex index) {
  final entries = index.entries
      .where((e) => e.name != null && !_commonApiSymbols.contains(e.name!))
      .toList();
  final hrefToQualifiedNames = <String, String>{};
  for (final e in entries) {
    if (e.href != null && e.qualifiedName != null) {
      hrefToQualifiedNames[e.href!] = e.qualifiedName!;
    }
  }
  final apiElements = <ApiElement>[];
  for (final e in entries) {
    final kind = e.kind == null ? null : kindNames[e.kind!];
    final showHref = e.isLibrary || e.isClass;
    final parent = hrefToQualifiedNames[e.enclosedBy?.href ?? ''];
    apiElements.add(ApiElement(
      name: e.name!,
      kind: kind,
      parent: parent,
      source: null,
      href: showHref ? e.href : null,
      documentation: (e.desc == null || e.desc!.isEmpty) ? null : e.desc,
    ));
  }

  /// Some symbols are repeated, and one instance may have a documentation, while
  /// the other misses it. E.g. an enum with a default constructor may have dartdoc
  /// on the enum type, but won't have anything on the (likely absent-from-code)
  /// constructor.
  final symbolsWithDocumentation = apiElements
      .where((e) => e.documentation != null)
      .map((e) => e.qualifiedName)
      .toSet();
  final symbolsMissingDocumentation = apiElements
      // filter out names that have documentation
      .whereNot((e) => symbolsWithDocumentation.contains(e.qualifiedName))
      // filter out names that are typically hidden constructors (e.g. `<A>.<A>`)
      // and the parent has documentation
      .whereNot((e) =>
          e.parent != null &&
          e.parent!.split('.').last == e.name &&
          symbolsWithDocumentation.contains(e.parent!))
      .map((e) => e.qualifiedName)
      .take(5)
      .toList();
  final documented = symbolsWithDocumentation.length;
  final total =
      symbolsWithDocumentation.length + symbolsMissingDocumentation.length;

  if (documented > 1000) {
    // Too much content, removing the documentation from everything except
    // libraries and classes.
    apiElements
        .where((e) => !e.isLibrary && !e.isClass)
        .forEach((e) => e.documentation = null);
  }

  return PubDartdocData(
    coverage: Coverage(
      documented: documented,
      total: total,
      symbolsMissingDocumentation: symbolsMissingDocumentation,
    ),
    apiElements: apiElements,
  );
}
