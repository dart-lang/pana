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

You can specify either a package (+ version) or a local directory to analyze:

```
Usage: pana [<options>] <package> [<version>]
       pana [<options>] --source path <directory>

Options:
  -j, --json            Output log items as JSON.
  -s, --source          The source used to find the package.
                        [hosted (default), path]
  
      --hosted-url      The server that hosts <package>.
                        (defaults to "https://pub.dartlang.org")
  
      --verbosity       Configure the details in the output.
                        [compact, normal (default), verbose]
  
      --[no-]warning    Shows the warning message before potentially destructive operation.
                        (defaults to on)
```
