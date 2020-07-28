[![Build Status](https://travis-ci.org/dart-lang/pana.svg?branch=master)](https://travis-ci.org/dart-lang/pana)

A library for analyzing Dart packages. It invokes executables from the Dart SDK
(or from the Flutter SDK if the package uses Flutter).

Reports are created in the following categories:

* [Follow Dart conventions](https://pub.dev/help/scoring#follow-dart-file-conventions)
* [Provide documentation](https://pub.dev/help/scoring#provide-documentation)
* [Support multiple platforms](https://pub.dev/help/scoring#support-multiple-platforms)
* [Pass static analysis](https://pub.dev/help/scoring#pass-static-analysis)
* [Support up-to-date dependencies](https://pub.dev/help/scoring#support-up-to-date-dependencies)

Used by the [Dart Package site](https://pub.dev/).

## Use as an executable

### Installation

```console
> pub global activate pana
```

### Usage

You can specify either a package (+ version) or a local directory to analyze:

```
Usage: pana [<options>] <published package name> [<version>]
       pana [<options>] --source path <local directory>

Options:
      --flutter-sdk     The directory of the Flutter SDK.
  -j, --json            Output log items as JSON.
  -s, --source          The source where the package is located (hosted on https://pub.dev, or local directory path).
                        [hosted, path (default)]
      --hosted-url      The server that hosts <package>.
                        (defaults to "https://pub.dev")
  -l, --line-length     The line length to use with dartfmt.
      --[no-]hosted     Shortcut to `--source hosted`.
      --[no-]verbose    Print the full JSON output instead of the markdown report.
      --[no-]warning    Shows the warning message before potentially destructive operation.
                        (defaults to on)
```
