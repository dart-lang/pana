// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import 'dartdoc_internals.dart';

part 'dartdoc_index.g.dart';

/// The parsed content of the `index.json` generated by dartdoc.
class DartdocIndex {
  final List<DartdocIndexEntry> entries;

  DartdocIndex(this.entries);

  factory DartdocIndex.parseJsonText(String content) {
    return DartdocIndex.fromJsonList(json.decode(content) as List);
  }

  factory DartdocIndex.fromJsonList(List<Object?> jsonList) {
    final list = jsonList
        .map((item) => DartdocIndexEntry.fromJson(item as Map<String, dynamic>))
        .toList();
    return DartdocIndex(list);
  }

  late final libraryRelativeUrls = Map<String, String>.fromEntries(
    entries
        .where((e) => e.isLibrary && e.qualifiedName != null && e.href != null)
        .map(
          (e) => MapEntry<String, String>(
            e.qualifiedName!.split('.').first,
            e.href!,
          ),
        ),
  );

  String toJsonText() => json.encode(entries);
}

@JsonSerializable(includeIfNull: false)
class DartdocIndexEntry {
  final String? name;
  final String? qualifiedName;
  final String? href;
  final int? kind;
  final int? packageRank;
  final int? overriddenDepth;
  final String? packageName;
  final String? desc;
  final DartdocIndexEntryEnclosedBy? enclosedBy;

  DartdocIndexEntry({
    required this.name,
    required this.qualifiedName,
    required this.href,
    this.kind,
    this.packageRank,
    this.overriddenDepth,
    this.packageName,
    this.desc,
    this.enclosedBy,
  });

  factory DartdocIndexEntry.fromJson(Map<String, dynamic> json) =>
      _$DartdocIndexEntryFromJson(json);

  Map<String, dynamic> toJson() => _$DartdocIndexEntryToJson(this);

  /// Weather the entry is a top-level library:
  /// - pre-8.3.0 the file ended with `-library.html`
  /// - with 8.3.0 the reference is a top-level directory with no slash in it
  late final isLibrary = isHrefALibrary(href);

  /// Whether the entry is a class declaration.
  bool get isClass => href != null && href!.endsWith('-class.html');
}

@JsonSerializable(includeIfNull: false)
class DartdocIndexEntryEnclosedBy {
  final String? name;
  final int? kind;
  final String? href;

  DartdocIndexEntryEnclosedBy({
    this.name,
    this.kind,
    this.href,
  });

  factory DartdocIndexEntryEnclosedBy.fromJson(Map<String, dynamic> json) =>
      _$DartdocIndexEntryEnclosedByFromJson(json);

  Map<String, dynamic> toJson() => _$DartdocIndexEntryEnclosedByToJson(this);
}
