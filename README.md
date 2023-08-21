[![Build Status](https://github.com/dart-lang/pana/workflows/Dart%20CI/badge.svg)](https://github.com/dart-lang/pana/actions?query=workflow%3A"Dart+CI"+branch%3Amaster)

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
dart pub global activate pana
```

### Usage

You can specify either a package (+ version) or a local directory to analyze:

```
Usage: pana [<options>] --hosted <published package name> [<version>]
       pana [<options>] <local directory>

Options:
      --dart-sdk               The directory of the Dart SDK.
      --flutter-sdk            The directory of the Flutter SDK.
      --exit-code-threshold    The exit code will indicate if (max - granted points) <= threshold.
  -j, --json                   Output log records and full report as JSON.
      --hosted-url             The server that hosts <package>.
                               (defaults to "https://pub.dev")
  -l, --line-length            The line length to use with dart format.
      --hosted                 Download and analyze a hosted package (from https://pub.dev).
      --[no-]warning           Shows the warning message before potentially destructive operation.
                               (defaults to on)
```
