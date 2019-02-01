// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:markdown/markdown.dart';
import 'package:meta/meta.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;

import 'model.dart';

/// The extracted content of a markdown file.
class ScannedMarkdownContent {
  String parseError;
  List<String> images;
  List<String> links;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'parseError': parseError,
        'images': images,
        'links': links,
      };
}

/// Scans a markdown text and extracts its content.
ScannedMarkdownContent scanMarkdownText(String text) {
  try {
    final htmlText = markdownToHtml(text);
    final html = html_parser.parseFragment(htmlText);
    final images = html
        .querySelectorAll('img')
        .where((e) => e.attributes.containsKey('src'))
        .map((e) => e.attributes['src'])
        .toList();
    final links = html
        .querySelectorAll('a')
        .where((e) => e.attributes.containsKey('href'))
        .map((e) => e.attributes['href'])
        .toList();
    return ScannedMarkdownContent()
      ..images = Set<String>.from(images).toList()
      ..links = Set<String>.from(links).toList();
  } catch (e) {
    return ScannedMarkdownContent()..parseError = e.toString();
  }
}

/// Scans a markdown file and extracts its content.
Future<ScannedMarkdownContent> scanMarkdownFileContent(File file) async {
  final text = await file.readAsString();
  return scanMarkdownText(text);
}

/// Analyze a markdown file and return a composite suggestion.
Future<Suggestion> analyzeMarkdownFile(File file, {String pkgDir}) async {
  final fileName = p.basename(file.path);
  final relativePath = p.relative(file.path, from: pkgDir);
  final analysis = await scanMarkdownFileContent(file);
  if (analysis.parseError != null) {
    return Suggestion.warning(
      SuggestionCode.markdownParseFailed,
      'Fix `$fileName`.',
      'Parsing `$fileName` failed with the following error: `${analysis.parseError}`.',
      score: 50.0,
      file: relativePath,
    );
  }

  final checked = await _checkLinks(analysis.images);
  // TODO: warn about relative image URLs
  // TODO: warn about insecure links
  // TODO: warn about relative links
  // TODO: consider checking whether the URL exists and returns HTTP 200.

  final issues = <String>[];
  var score = 0.0;
  if (checked.unparsed.isNotEmpty) {
    final count = checked.unparsed.length;
    final first = checked.unparsed.first;
    score += count;
    final pluralize = count == 1 ? 'link' : 'links';
    issues.add('Unable to parse $count image $pluralize (e.g. `$first`).');
  }
  if (checked.insecure.isNotEmpty) {
    final count = checked.insecure.length;
    final first = checked.insecure.first;
    score += count * 2;
    final pluralize = count == 1 ? 'link is' : 'links are';
    issues.add(
        '$count image $pluralize insecure (e.g. `$first`), use `https` URLs instead.');
  }
  if (score > 0.0) {
    return Suggestion.hint(
      SuggestionCode.markdownContent,
      'Update `$fileName`.',
      issues.join('\n\n'),
      score: score,
      file: relativePath,
    );
  }

  return null;
}

Future<_Links> _checkLinks(List<String> links) async {
  final unparsed = <String>[];
  final parsed = <String>[];
  final insecure = <String>[];

  for (var link in links) {
    final uri = Uri.tryParse(link);
    if (uri == null) {
      unparsed.add(link);
      continue;
    }
    parsed.add(link);
    if (uri.scheme != null && uri.scheme.isNotEmpty && uri.scheme != 'https') {
      insecure.add(link);
    }
  }
  return _Links(unparsed: unparsed, parsed: parsed, insecure: insecure);
}

class _Links {
  final List<String> unparsed;
  final List<String> parsed;
  final List<String> insecure;

  _Links({
    @required this.unparsed,
    @required this.parsed,
    @required this.insecure,
  });
}
