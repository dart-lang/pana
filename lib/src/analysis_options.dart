// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const String analysisOptions = '''
analyzer:
  strong-mode: true

# Source of linter options:
# http://dart-lang.github.io/linter/lints/options/options.html

linter:
  rules:
    - hash_and_equals
    - valid_regexps
#    - annotate_overrides
#    - camel_case_types
#    - cancel_subscriptions
#    - close_sinks
#    - implementation_imports
#    - no_adjacent_strings_in_list
#    - prefer_is_empty
#    - prefer_is_not_empty
#    - test_types_in_equals
''';
