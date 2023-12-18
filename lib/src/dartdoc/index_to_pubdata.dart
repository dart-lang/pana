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
    final showHref = e.isLibrary || e.isClass;
    final parent = hrefToQualifiedNames[e.enclosedBy?.href ?? ''];
    apiElements.add(ApiElement(
      name: e.name!,
      parent: parent,
      source: null,
      href: showHref ? e.href : null,
      documentation: (e.desc == null || e.desc!.isEmpty) ? null : e.desc,
    ));
  }

  final symbolsWithDocumentation = apiElements
      .where((e) => e.documentation != null)
      .map((e) => e.qualifiedName)
      .toSet();
  final symbolsMissingDocumentation = apiElements
      // filter out names that have documentation
      .whereNot((e) => symbolsWithDocumentation.contains(e.qualifiedName))

      // Some symbols are present here without being in the code. E.g. an enum may
      // omit the default constructor, and we would report it as undocumented here.
      // Filtering out typically hidden constructors (e.g. `<A>.<A>`) if the parent
      // type has a documentation.
      .whereNot((e) =>
          e.parent != null &&
          e.parent!.split('.').last == e.name &&
          symbolsWithDocumentation.contains(e.parent!))
      .map((e) => e.qualifiedName)
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
      symbolsMissingDocumentation: symbolsMissingDocumentation.take(5).toList(),
    ),
    apiElements: apiElements,
  );
}
