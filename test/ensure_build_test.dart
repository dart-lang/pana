@Tags(['presubmit-only'])
@OnPlatform({
  // TODO(sigurdm): Investigate. Perhaps to do with line-endings?
  'windows': Skip('The build on windows does not come out clean')
})
import 'package:build_verify/build_verify.dart';
import 'package:test/test.dart';

void main() {
  test('ensure_build', expectBuildClean);
}
