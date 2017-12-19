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
    - camel_case_types
    - hash_and_equals
    - iterable_contains_unrelated_type
    - list_remove_unrelated_type
    - unrelated_type_equality_checks
    - valid_regexps
''';

// Keep it updated with
// https://github.com/flutter/flutter/blob/master/packages/flutter/lib/analysis_options_user.yaml
const String flutterAnalysisOptions = '''
analyzer:
  language:
    enableStrictCallChecks: true
    enableSuperMixins: true
    enableAssertInitializer: true
  strong-mode: true
  errors:
    # treat missing required parameters as a warning (not a hint)
    missing_required_param: warning
    # treat missing returns as a warning (not a hint)
    missing_return: warning
    # allow having TODOs in the code
    todo: ignore

# Source of linter options:
# http://dart-lang.github.io/linter/lints/options/options.html

linter:
  rules:
    - camel_case_types
    - hash_and_equals
    - iterable_contains_unrelated_type
    - list_remove_unrelated_type
    - unrelated_type_equality_checks
    - valid_regexps
''';
