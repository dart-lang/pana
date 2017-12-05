[![Build Status](https://travis-ci.org/dart-lang/pana.svg?branch=master)](https://travis-ci.org/dart-lang/pana)

A library for analyzing Dart packages.

* Validates the code using [Dart Analyzer](https://www.dartlang.org/tools/analyzer).
* Checks code formatting.
* Checks for outdated dependencies.
* Infers supported platforms: Flutter, web, and/or server.

Used by the [Dart Package site](https://pub.dartlang.org/).

## Use as an executable

### Installation

```console
> pub global activate pana
```

### Usage

```
Usage: pana [<options>] <package name> [<package version>]

Options:
  -j, --json    Output log items as JSON.
```
