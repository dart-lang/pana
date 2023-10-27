// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

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
    final kind = kindNames[e.kind!]!;
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
  return PubDartdocData(
    coverage: Coverage(
      documented: apiElements.where((e) => e.documentation != null).length,
      total: apiElements.length,
    ),
    apiElements: apiElements,
  );
}
