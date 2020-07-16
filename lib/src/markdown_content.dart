// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:markdown/markdown.dart';
import 'package:meta/meta.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:source_span/source_span.dart';

import 'model.dart';

/// The extracted content of a markdown file.
class ExctractedMarkdownContent {
  final List<Link> images;
  final List<Link> links;

  ExctractedMarkdownContent({this.images, this.links});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'images': images.map((l) => l.url).toList(),
        'links': links.map((l) => l.url).toList(),
      };
}

/// Scans a markdown text and extracts its content.
ExctractedMarkdownContent scanMarkdownText(String text, Uri sourceUrl) {
  final htmlText = markdownToHtml(text);
  final html = html_parser.parseFragment(htmlText,
      sourceUrl: sourceUrl.toString(), generateSpans: true);
  return ExctractedMarkdownContent(
      images: _unique(html
          .querySelectorAll('img')
          .where((e) => e.attributes.containsKey('src'))
          .map((e) => Link(e.attributes['src'], e.sourceSpan))),
      links: _unique(html
          .querySelectorAll('a')
          .where((e) => e.attributes.containsKey('href'))
          .map((e) => Link(e.attributes['href'], e.sourceSpan))));
}

List<T> _unique<T>(Iterable<T> l) => l.toSet().toList();

/// Scans a markdown file and extracts its content.
Future<ExctractedMarkdownContent> scanMarkdownFileContent(File file) async {
  final text = await file.readAsString();
  return scanMarkdownText(text, file.uri);
}

/// Analyze a markdown file and return a composite suggestion.
Future<Suggestion> analyzeMarkdownFile(File file, {String pkgDir}) async {
  final fileName = p.basename(file.path);
  final relativePath = p.relative(file.path, from: pkgDir);
  final analysis = await scanMarkdownFileContent(file);

  final checked = await checkLinks(analysis.images);
  // TODO: warn about relative image URLs
  // TODO: warn about insecure links
  // TODO: warn about relative links
  // TODO: consider checking whether the URL exists and returns HTTP 200.

  final issues = <String>[];
  var score = 0.0;
  if (checked.unparsed.isNotEmpty) {
    final count = checked.unparsed.length;
    final first = checked.unparsed.first.url;
    score += count;
    final pluralize = count == 1 ? 'link' : 'links';
    issues.add('Unable to parse $count image $pluralize (e.g. `$first`).');
  }
  if (checked.insecure.isNotEmpty) {
    final count = checked.insecure.length;
    final first = checked.insecure.first.url;
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
    if (uri.scheme != null &&
        uri.scheme.isNotEmpty &&
        uri.scheme != 'https' &&
        uri.scheme != 'mailto') {
      insecure.add(link);
    }
  }
  return Links(unparsed: unparsed, parsed: parsed, insecure: insecure);
}

class Link {
  final String url;
  final SourceSpan span;
  Link(this.url, this.span);
}

class Links {
  final List<Link> unparsed;
  final List<Link> parsed;
  final List<Link> insecure;

  Links({
    @required this.unparsed,
    @required this.parsed,
    @required this.insecure,
  });
}
