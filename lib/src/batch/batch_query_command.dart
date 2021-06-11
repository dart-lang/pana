// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:http/http.dart' as http;

/// Queries pub.dev to select packages for comparative analysis.
///
/// The command fetches the list of packages specified by the query
/// text of the command, ordered by the current top package scores first.
///
/// Additional filters are applied in the order of this list, up to the
/// `--limit` parameter.
class BatchQueryCommand extends Command {
  final _client = http.Client();

  @override
  String get name => 'query';

  @override
  String get description => 'Query pub.dev to select packages.';

  @override
  final argParser = ArgParser(allowTrailingOptions: true)
    ..addOption(
      'max-age-days',
      defaultsTo: '0',
      help: 'The maximum age of the latest published version in days.',
    )
    ..addOption(
      'sort',
      defaultsTo: 'popularity',
      allowed: ['top', 'created', 'updated', 'popularity', 'like', 'points'],
      help: 'The default order (always decreasing).',
    )
    ..addOption(
      'limit',
      defaultsTo: '100',
      help: 'Limits the number of packages (ordered by total score).',
    )
    ..addOption(
      'output',
      help: 'Write packages to file (stdout otherwise).',
    );

  @override
  Future<void> run() async {
    final limit = int.parse(argResults!['limit'] as String);
    final maxAgeDays = int.parse(argResults!['max-age-days'] as String);
    final sort = argResults!['sort'] as String;
    final output = argResults!['output'];
    final query = argResults!.rest.join(' ');

    final selected = <String>{};
    var page = 1;
    while (selected.length < limit) {
      final list = await _getPackages(query, sort, page++);
      for (final p in list) {
        if (maxAgeDays > 0) {
          final ageInDays = await _ageInDays(p);
          if (ageInDays > maxAgeDays) continue;
        }
        selected.add(p);
        // ignore: invariant_booleans
        if (selected.length >= limit) {
          break;
        }
      }
      if (list.isEmpty) break;
    }
    _client.close();

    final result = (selected.toList()..sort()).join('\n');

    if (output != null) {
      await File(output as String).writeAsString(result);
    } else {
      print(result);
    }
  }

  Future<List<String>> _getPackages(
      String? query, String sort, int page) async {
    final rs = await _client
        .get(Uri.parse('https://pub.dev/api/search').replace(queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      if (page > 1) 'page': page.toString(),
      'sort': sort,
    }));
    if (rs.statusCode != 200) {
      throw AssertionError('Unexpected status code: ${rs.statusCode}');
    }
    final map = json.decode(rs.body) as Map<String, dynamic>;
    return (map['packages'] as List)
        .cast<Map>()
        .map((m) => m['package'] as String)
        .toList();
  }

  Future<int> _ageInDays(String package) async {
    final rs = await _client
        .get((Uri.parse('https://pub.dartlang.org/api/packages/$package')));
    if (rs.statusCode != 200) {
      throw AssertionError('Unexpected status code: ${rs.statusCode}');
    }
    final map = json.decode(rs.body) as Map<String, dynamic>;
    final latest = map['latest'] as Map<String, dynamic>;
    final published = DateTime.parse(latest['published'] as String);
    return DateTime.now().difference(published).inDays;
  }
}
