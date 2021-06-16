// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:markdown/markdown.dart';
import 'package:source_span/source_span.dart';

import 'utils.dart';

/// The extracted content of a markdown file.
class ExctractedMarkdownContent {
  final List<Link> images;
  final List<Link> links;
  final bool isMalformedUtf8;
  final double nonAsciiRatio;

  ExctractedMarkdownContent({
    required this.images,
    required this.links,
    required this.isMalformedUtf8,
    required this.nonAsciiRatio,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'images': images.map((l) => l.url).toList(),
        'links': links.map((l) => l.url).toList(),
        'isMalformedUtf8': isMalformedUtf8,
        'nonAsciiRatio': nonAsciiRatio,
      };
}

/// Scans a markdown text and extracts its content.
ExctractedMarkdownContent _scanMarkdownText(
    String text, Uri sourceUrl, bool isMalformedUtf8) {
  final htmlText = markdownToHtml(text);
  final html = html_parser.parseFragment(htmlText,
      sourceUrl: sourceUrl.toString(), generateSpans: true);
  return ExctractedMarkdownContent(
    images: _unique(html
        .querySelectorAll('img')
        .where((e) => e.attributes.containsKey('src'))
        .map((e) => Link(e.attributes['src']!, e.sourceSpan))),
    links: _unique(html
        .querySelectorAll('a')
        .where((e) => e.attributes.containsKey('href'))
        .map((e) => Link(e.attributes['href']!, e.sourceSpan))),
    isMalformedUtf8: isMalformedUtf8,
    nonAsciiRatio: nonAsciiRuneRatio(text),
  );
}

List<T> _unique<T>(Iterable<T> l) => l.toSet().toList();

/// Scans a markdown file and extracts its content.
Future<ExctractedMarkdownContent> scanMarkdownFileContent(File file) async {
  final bytes = await file.readAsBytes();
  String text;
  var isMalformedUtf8 = false;
  try {
    text = utf8.decode(bytes, allowMalformed: false);
  } on FormatException {
    text = utf8.decode(bytes, allowMalformed: true);
    isMalformedUtf8 = true;
  }
  return _scanMarkdownText(text, file.uri, isMalformedUtf8);
}

Future<Links> checkLinks(List<Link> links) async {
  final unparsed = <Link>[];
  final parsed = <Link>[];
  final insecure = <Link>[];

  for (var link in links) {
    final uri = Uri.tryParse(link.url);
    if (uri == null) {
      unparsed.add(link);
      continue;
    }
    parsed.add(link);
    if (uri.scheme.isNotEmpty &&
        uri.scheme != 'https' &&
        uri.scheme != 'mailto') {
      insecure.add(link);
    }
  }
  return Links(unparsed: unparsed, parsed: parsed, insecure: insecure);
}

class Link {
  final String url;
  final SourceSpan? span;
  Link(this.url, this.span);
}

class Links {
  final List<Link> unparsed;
  final List<Link> parsed;
  final List<Link> insecure;

  Links({
    required this.unparsed,
    required this.parsed,
    required this.insecure,
  });
}
