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
Usage: pana [<options>] <published package name> [<version>]
       pana [<options>] --source path <local directory>

Options:
      --flutter-sdk     The directory of the Flutter SDK.
  -j, --json            Output log items as JSON.
  -s, --source          The source where the package is located (hosted on https://pub.dartlang.org, or local directory path).
                        [hosted (default), path]
  
      --hosted-url      The server that hosts <package>.
                        (defaults to "https://pub.dartlang.org")
  
      --verbosity       Configure the details in the output.
                        [compact, normal (default), verbose]
  
      --[no-]warning    Shows the warning message before potentially destructive operation.
                        (defaults to on)
```

## Scoring

### Health score

A package gets `0.0` if any major analyzer process fails (e.g. `pub upgrade`,
`dartanalyzer` or `dartfmt`).

Otherwise the score starts with `1.0`, and
- analyzer errors reduce it by 25%
- analyzer warnings reduce it by 5%
- analyzer hints reduce it by 0.5%
- platform conflicts reduce it by 0.25 points (absolute reduction)

`health = 0.75^errors * 0.95^warnings * 0.995^hints - 0.25*conflicts`

[Pub site](https://pub.dartlang.org/) transforms this score into the [0 - 100] range.

### Maintenance score

A package starts with `100` points, and the following detected issues have point reductions:
- uses `strong-mode: false` in `analysis_options.yaml` (-50 points)
- SDK constraint is missing from `pubspec.yaml` (-50 points)
- `readme.md` missing (-30 points)
- `changelog.md` missing (-20 points)
- has platform conflicts (-20 points)
- has unconstrained dependencies (-20 points)
- `description` is too short (<60 characters) (-20 points)
- `homepage` points to non-existent URL (-20 points)
- `homepage` is not helpful (e.g. pointing to `http://localhost/`) (-10 points)
- `documentation` points to non-existent URL (-10 points)
- `documentation` is not helpful (e.g. pointing to `http://localhost/`) (-10 points)
- `description` is too long (>180 characters) (-10 points)
- package has no example file (-10 points)
- uses old `.analysis_options` file (-10 points)
- uses pre-v0.1 release versioning (`0.0.*`) (-10 points)
- uses pre-release versioning (`*.*.*-beta2`) (-5 points)

On top of that, [pub site](https://pub.dartlang.org/) applies an age restriction:
 - outdated packages (age older than two years) are reduced to 0
 - old packages (age between 1 and 2 years) get linear reduction (1.5 years old get 50% reduction)
