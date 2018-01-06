// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';
import 'package:pana/src/version.dart';

import 'shared.dart';

final data = new E2EData('skiplist', '0.1.0', _data);

final _data = {
  'panaVersion': panaPkgVersion.toString(),
  'sdkVersion': isSemVer,
  'packageName': 'skiplist',
  'packageVersion': '0.1.0',
  'pubspec': {
    'version': '0.1.0',
    'name': 'skiplist',
    'dependencies': {'quiver_iterables': '>=1.0.0 <2.0.0'},
    'author': 'Steven Roose <stevenroose@gmail.com>',
    'description': 'A skiplist implementation in Dart.',
    'homepage': 'https://github.com/stevenroose/dart-skiplist',
    'dev_dependencies': {'test': '>=0.12.7 <0.13.0'}
  },
  'pkgResolution': {
    'dependencies': [
      {
        'package': 'meta',
        'dependencyType': 'transitive',
        'constraintType': 'inherited',
        'resolved': isNotNull,
      },
      {
        'package': 'quiver_iterables',
        'dependencyType': 'direct',
        'constraintType': 'normal',
        'constraint': '>=1.0.0 <2.0.0',
        'resolved': isNotNull,
      },
      {
        'package': 'test',
        'dependencyType': 'dev',
        'constraintType': 'normal',
        'constraint': '>=0.12.7 <0.13.0'
      }
    ]
  },
  'dartFiles': {
    'lib/skiplist.dart': {
      'uri': 'package:skiplist/skiplist.dart',
      'size': 8066,
      'isFormatted': false,
      'codeProblems': [
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 77,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.[]\' (\'(K) → V\') isn\'t a subtype of \'Map<K, V>.[]\' (\'(Object) → V\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 77,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.[]\' (\'(K) → V\') isn\'t a subtype of \'MapMixin<K, V>.[]\' (\'(Object) → V\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 91,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.containsKey\' (\'(K) → bool\') isn\'t a subtype of \'Map<K, V>.containsKey\' (\'(Object) → bool\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 91,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.containsKey\' (\'(K) → bool\') isn\'t a subtype of \'MapMixin<K, V>.containsKey\' (\'(Object) → bool\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 116,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.remove\' (\'(K) → V\') isn\'t a subtype of \'Map<K, V>.remove\' (\'(Object) → V\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 116,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.remove\' (\'(K) → V\') isn\'t a subtype of \'MapMixin<K, V>.remove\' (\'(Object) → V\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 165,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.containsValue\' (\'(V) → bool\') isn\'t a subtype of \'Map<K, V>.containsValue\' (\'(Object) → bool\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_METHOD_OVERRIDE',
          'file': 'lib/skiplist.dart',
          'line': 165,
          'col': 3,
          'description':
              'Invalid override. The type of \'SkipList.containsValue\' (\'(V) → bool\') isn\'t a subtype of \'MapMixin<K, V>.containsValue\' (\'(Object) → bool\').'
        },
        {
          'severity': 'ERROR',
          'errorType': 'COMPILE_TIME_ERROR',
          'errorCode': 'STRONG_MODE_INVALID_CAST_FUNCTION_EXPR',
          'file': 'lib/skiplist.dart',
          'line': 168,
          'col': 40,
          'description':
              'The function expression type \'(_SkipListEntry<Comparable<dynamic>, dynamic>) → Comparable<dynamic>\' isn\'t of type \'(_SkipListEntry<Comparable<dynamic>, dynamic>) → K\'. This means its parameter or return type does not match what is expected. Consider changing parameter type(s) or the returned type(s).'
        }
      ],
      'directLibs': [
        'dart:collection',
        'dart:math',
        'package:quiver_iterables/iterables.dart'
      ],
      'transitiveLibs': [
        'dart:collection',
        'dart:math',
        'package:meta/meta.dart',
        'package:quiver_iterables/iterables.dart'
      ],
      'platform': {'worksEverywhere': true},
      'fitness': {'magnitude': 185.0, 'shortcoming': 185.0}
    }
  },
  'platform': {
    'worksEverywhere': true,
    'reason': 'No platform restriction found in libraries.',
  },
  'licenses': [
    {
      'path': 'LICENSE',
      'name': 'MIT',
      'url': 'https://github.com/stevenroose/dart-skiplist/blob/master/LICENSE',
    },
  ],
  'maintenance': {
    'missingChangelog': false,
    'missingExample': true,
    'missingReadme': false,
    'missingAnalysisOptions': true,
    'oldAnalysisOptions': false,
    'strongModeEnabled': false,
    'isExperimentalVersion': true,
    'isPreReleaseVersion': false,
    'errorCount': 1,
    'warningCount': 0,
    'hintCount': 0,
    'suggestions': [
      {
        'level': 'hint',
        'title': 'Maintain an example.',
        'description':
            'Create a short demo in the `example/` directory to show how to use this package. Common file name patterns include: `main.dart`, `example.dart` or you could also use `skiplist.dart`.',
        'penalty': {'amount': 5, 'fraction': 0}
      },
      {
        'level': 'hint',
        'title': 'Package is pre-v1 release.',
        'description':
            'While there is nothing inherently wrong with versions of `0.*.*`, it usually means that the author is still experimenting with the general direction API.',
        'penalty': {'amount': 10, 'fraction': 0}
      },
      {
        'level': 'hint',
        'title': 'The description is too short.',
        'description':
            'Add more detail about the package, what it does and what is its target use case. Try to write at least 60 characters.',
        'penalty': {'amount': 20, 'fraction': 0}
      },
      {
        'level': 'warning',
        'title': 'Fix issues reported by `dartanalyzer`.',
        'description': '`dartanalyzer` reported 1 error(s) and 0 warning(s).',
        'penalty': {'amount': 0, 'fraction': 500}
      }
    ],
  },
  'fitness': {'magnitude': 185.0, 'shortcoming': 185.0},
  'suggestions': [
    {
      'level': 'error',
      'title': 'Fix `lib/skiplist.dart`.',
      'description':
          'Strong-mode analysis of `lib/skiplist.dart` failed with the following error:\n\n'
          'line: 77 col: 3  \n'
          'Invalid override. The type of \'SkipList.[]\' (\'(K) → V\') isn\'t a subtype of \'Map<K, V>.[]\' (\'(Object) → V\').\n'
          '',
      'file': 'lib/skiplist.dart',
    },
  ],
};
