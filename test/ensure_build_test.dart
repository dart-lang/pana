@Tags(['presubmit-only'])
import 'dart:io';

import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test(
    'ensure_build',
    () async {
      // TODO(sigurdm): investigate why the build doesn't come clean on
      // Windows or on Mac.
      if (!Platform.isWindows && !Platform.isMacOS) {
        await expectBuildClean();
      }
    },
    timeout: const Timeout.factor(4),
  );
}
