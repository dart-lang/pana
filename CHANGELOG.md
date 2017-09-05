## (next release)

* **Breaking changes**

  * Renamed `AnalyzerIssue` -> `ToolProblem`
    * Renamed `Summary.issues` -> `toolProblems`
    * Renamed `AnalyzerIssue.scope` -> `tool`
    * Renamed `AnalyzerScopes` -> `ToolNames`

  * Renamed `AnalyzerOutput` -> `CodeProblem`
    * Renamed `Summary.analyzerItems` and `DartFileSummary.analyzerItems` -> `codeProblems`

  * Refactored `CodeProblem` (previously `AnalyzerOutput`):
    * Split up `type`, new fields: `severity`, `errorType`, `errorCode`
    * Renamed `error` to `description`

## 0.3.0

* Removed `PlatformSummary.package` in favor of `PlatformSummary.pubspec` of
  (new) type `PubspecPlatform`.

* Renamed `KnownPlatforms` to `PlatformFlags`. Also:
  * Removed `mirrors`, `browser` and `standalone`.
  * Renamed `native` to `dartExtension`.

* `PlatformInfo`
  * Now store `dart:*` references directly in `uses`.
  * `worksInStandalone` renamed to `worksOnServer`.
  * Other `.worksIn*` renamed to `worksOn*`.
  * Added `String get description` which returns a simple `String` description
    of the supported platforms. Examples: `everywhere`, `flutter`, 
    `server, web`, `conflict`.
  * Removed `angular` as a value in `uses`.

## 0.2.4

* Detect native extensions.

* Detect licenses.

## 0.2.3

* Lot's of stability improvements.

* Improvements to error handling.

## 0.2.2

* Lot's of cleanup to JSON output.

* Improved stability.

* Platform detection basics.

## 0.2.1

* Added support for `flutter` packages.

* Expanded analysis to include transitive dependencies.

* Added scoring library.

* Moved the repo to `dart-lang`.

## 0.2.0

* A lot of tweaks. Still under heavy development.

## 0.0.1

* Initial version.
