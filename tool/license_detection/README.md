# Evaluate license detection changes

The tools in this directory help to evaluate changes in the license-detection code,
by downloading licenses from `pub.dev` and running a difference on the license
detection output before and after the changes.

The cached licenses are stored in `.dart_tool/pana/license-cache/`.

 - Use `download_pub_dev_licenses.sh` to populate the directory with fresh licenses from `pub.dev`.
 - Run `batch_analyse_licenses.dart` before and after a license detection change.
 - Run `compare_analysis.dart` with the before and after file of the prior change.
