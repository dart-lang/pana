# pub.dev licenses
The `licenses/` directory could contain the licenses of the latest versions of packages on `pub.dev`.

## Evaluate license detection changes

 - Use `download_pub_licenses.sh` to populate the directory with fresh licenses.
 - Run `batch_analyze_licenses.dart` before and after a license detection change.
 - Run `batch_compare_lincenses.dart` with the before and after file of the prior change.
