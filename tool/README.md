A good sanity check:
```console
cat tool/pkg_sample.txt | xargs -n 2 -P 8 dart --checked bin/main.dart
```