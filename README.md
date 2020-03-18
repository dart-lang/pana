[![Build Status](https://travis-ci.org/dart-lang/pana.svg?branch=master)](https://travis-ci.org/dart-lang/pana)

A library for analyzing Dart packages. It invokes executables from the Dart SDK
(or from the Flutter SDK if the package uses Flutter).

* Checks for outdated dependencies (calls `pub upgrade` or `flutter pub upgrade`).
* Validates the code using [Dart Analyzer](https://dart.dev/tools/dartanalyzer).
* Checks code formatting (`dartfmt` or `flutter format`).
* Infers supported platforms: Flutter, web, and/or other (e.g console/server).
* Creates suggestions to improve the package.

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
                        [hosted (default), path]
      --hosted-url      The server that hosts <package>.
                        (defaults to "https://pub.dev")
  -l, --line-length     The line length to use with dartfmt.
      --verbosity       Configure the details in the output.
                        [compact, normal (default), verbose]
      --[no-]scores     Include scores in the output JSON.
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
- analyzer hints reduce it by 0.5% (maximum penalty: 25%)
- platform conflicts reduce it by 0.25 points (absolute reduction)

`health = 0.75^errors * 0.95^warnings * max(0.75, 0.995^hints) - 0.25*conflicts`

[Pub site](https://pub.dev/) transforms this score into the [0 - 100] range.

### Maintenance score

A package starts with `100` points, and the following detected issues have point reductions:
- unable to parse `pubspec.yaml` with strict parsing (100 points)
- uses `strong-mode: false` in `analysis_options.yaml` (-50 points)
- SDK constraint is missing from `pubspec.yaml` (-50 points)
- using `git` dependencies (-100 points, -50 if using commit hashes)
- unable to parse markdown content (-50 points)
- `readme.md` missing (-30 points)
- `changelog.md` missing (-20 points)
- unable to detect valid SDKs (-20 points)
- has unconstrained dependencies (-20 points)
- does not allow latest stable SDK (-20 points)
- `description` is too short (<60 characters) (-20 points)
- `description` contains too many non-ASCII characters (-20 points)
- `homepage` points to non-existent URL (-20 points)
- `homepage` is not helpful (e.g. pointing to `http://localhost/`) (-10 points)
- `homepage` is insecure (not using `https`) (-5 points)
- `documentation` points to non-existent URL (-10 points)
- `documentation` is not helpful (e.g. pointing to `http://localhost/`) (-10 points)
- `documentation` is insecure (not using `https`) (-5 points)
- `repository` points to non-existent URL (-10 points)
- `repository` is not helpful (e.g. pointing to `http://localhost/`) (-10 points)
- `repository` is insecure (not using `https`) (-5 points)
- `issue_tracker` points to non-existent URL (-10 points)
- `issue_tracker` is not helpful (e.g. pointing to `http://localhost/`) (-10 points)
- `issue_tracker` is insecure (not using `https`) (-5 points)
- `description` is too long (>180 characters) (-10 points)
- does not support the latest version of its direct dependencies (-10 points)
- package has no example file (-10 points)
- uses old `.analysis_options` file (-10 points)
- uses pre-v0.1 release versioning (`0.0.*`) (-10 points)
- uses pre-release versioning (`*.*.*-beta2`) (-5 points)
- image links in markdown content are insecure (not using `https`) (-2 points per link) 
- image links in markdown content are broken (unable to parse) (-1 point per link) 
- `changelog.md`, `readme.md` or example content is too large (-1 point per every 1kb above 128kb).
- `pubspec.yaml` too large (-1 point per every 1kb above 32kb).

On top of that, [pub site](https://pub.dev/) applies an age restriction:
 - outdated packages (age older than two years) are reduced to 0
 - old packages (age between 1 and 2 years) get linear reduction (1.5 years old get 50% reduction)
