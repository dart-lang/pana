@Tags(['presubmit-only'])
import 'dart:io';

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test('ensure_build', expectBuildClean,
      skip:
          // TODO(sigurdm): investigate why we need this.
          Platform.isWindows ? 'Build does not look clean in windows' : false);
}
