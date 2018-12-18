## 0.12.9

* Analysis options used in code health scoring updated:
  * removed stale options,
  * included latest Flutter-enabled lints,
  * included latest stagehand-enabled lints.

* Downgrading `package:analyzer`.

## 0.12.8

* Code cleanup.

* Reduce the amount of warning+ level log messages when tools fail.

* Handle package with bad `pubspec.yaml`.

## 0.12.7

* Reduce the amount of logging when `dartfmt` fails due to an issue in the package.

* Display Dart SDK warning if package doesn't allow the latest Dart 2.X version.

## 0.12.6

* Bulk processing and comparison.

* Penalty for description using too many non-ASCII characters.

* Use `--dry-run` on executing flutter format.

* Retry the external process on downloading and listing packages.

* Use Flutter's internal Dart SDK to run `dartanalyzer` on Flutter packages.

## 0.12.5

* Increase the severity of missing SDK constraint.

* Make `example/readme.md` the first-level example-file candidate.

* Scores values should be consistently in the `[0.0-1.0]` range.

## 0.12.4

* Documented how scoring works.

* Estimate health score penalties.

## 0.12.3

* Increased `dartfmt` timeout to 5 minutes.

* Store basic stats in the analysis summary.

* Detect `example/readme.md` (or similar pattern) as an alternative to single `.dart` example.

## 0.12.2

* Bugfix: pre-v1 release should be pre-v0.1 instead.

## 0.12.1

* Bugfix: packages without Dart files failed the health checks.

## 0.12.0

**Breaking changes:**

* Named parameters in the following constructors: `Summary`, `DartFileSummary`, `PkgDependency`, `CodeProblem`. 

* Removed per-file and overall `Fitness`, using a top-level `Health` report instead.
  Follows the proposed changes that allow us to clearly communicate the scoring mechanism.

* Removed `Penalty` and using the simpler to understand `score` in place of it.

**Updates:**

* Use `flutter format` for Flutter packages.

* Support relative local path with `--source path`.

* Track tool failures and set health score to 0 if there is any.

## 0.11.8

* Support Dart 2 gold release.

* Remove `strong-mode: true` check and suggestion.

* Do not check existence of non-external URLs.

* API for external caching of URL existence checks.

## 0.11.7

* Suggestions for SDK constraint and Dart 2 compatibility.

## 0.11.6

* Updated report on `dartanalyzer` suggestions.

## 0.11.5

* Less verbose logging.

* Updated platform classification:
  * Library conflict rule is moved to the end of the evaluation.
  * Top file-related suggestions are directly exposed.
  * The bulk summary suggestion is more compact.

* Updated suggestion messages.

## 0.11.4

* Export libraries used by pub site.

* Update minimum SDK to `2.0.0-dev.42.0`
  * The SDK was effectively restricted to at least this version due to other
    dependencies.

* Better expose platform conflict reasons.

## 0.11.3

* Support changing part of the analysis result.

* Fix `dartdoc` timeout when using `pub global run`.

## 0.11.2

* `dartdoc` processing: do not exclude packages by default, as `dartdoc` `0.19` handles SDK links.

* expose `getAgeSuggestion` method for pub site

* Update `analyzer` dependency to `^0.32.0`.

## 0.11.1

* Upgrade CI to dev.54 and fix new deprecation warnings.

* Bugfix: do not initialize `dartdocSuccessful` with a value.

* Support `--flutter-sdk` in the `pana` binary.

## 0.11.0

**Breaking changes:**

* `DartSdk`, `FlutterSdk` and `PubEnvironment` is replaced with `ToolEnvironment`.

* `ToolEnvironment.runAnalyzer` returns the text output of the process.

* Consolidating options in `InspectOptions`, changing `PackageAnalyzer` APIs.

* Move all output-related data structure to `src/model.dart`:
  * `CodeProblem.parse` -> `parseCodeProblem`
  * `Maintenance.getMaintenanceScore` -> `getMaintenanceScore`
  * `PkgResolution.create` -> `createPkgResolution`

* Move all runtime/version info into `PanaRuntimeInfo` (and use it in `Summary`).

* Removed `Fitness.suggestions` (moved it to `DartFileSummary`)

Updates:

* Run `dartdoc` (optional) and report if it was not able to complete successfully.

* Added a top-level `models.dart` library exposing several of the data classes.

* Check `homepage` and `documentation` properties to point to an existing and external web page.

* `--verbose` command-line and `Verbosity` option to control the details in the analysis output.

## 0.10.6

* Enable Dart 2 Preview in analyzer options (including non-Flutter packages).

* Change platform classification of `dart:isolate`: no longer available on `web`.

* Treat `environment:` keys as dependent SDKs (e.g. `flutter`).

* Use `LibraryElement.hasExtUri` to detect `dart-ext:` imports.

* Detailed suggestion messages when package has conflicting platforms.

## 0.10.5

* Enable Dart 2 Preview in Flutter analyzer options.

## 0.10.4

* Fix CI test

* Flutter-specific suggestion messages for `dartfmt` and `dartanalyzer`.

## 0.10.3

* Fix end-to-end test (package dependency changed).

* Move pubspec stripping inside `PubEnvironment.runUpgrade` (`dartdoc` service will get it for free).

* Handle more repository URLs (e.g. `www.github.com`).

* Expose Flutter detection to clients, with better naming (`isFlutter` -> `usesFlutter`).

## 0.10.2

* Fix issue of not using the `PUB_CACHE` directory when it was set.

* Update `analyzer` to 0.31 and extends `quiver` version range.

* Fix issue where we were not passing the proper package directory variable.

* Expose all `dartanalyzer` and `dartfmt` problems as suggestions.

## 0.10.1

* Include component list in platform classification reasons.

* Do not report on unconstrained SDK dependencies.

* New platform component: `build`.

* Remove `dependency_overrides` from `pubspec.yaml`.

## 0.10.0

**BREAKING CHANGES**:

* Removed `DartPlatform.description` and `DartPlatform.descriptionAndReason`
  because we don't use them elsewhere and complicates the `PlatformNames`
  with `everywhere` and `undefined`.
    
* Removed `PlatformNames.everywhere` and `PlatformNames.undefined`, because
  we don't print these anywhere except in tests.

* Removed `PlatformNames.dartExtension`, because we use it only internally.

* Removed `DartPlatform.restrictedTo`, using the fields `components` and `uses` instead.

* Removed `PlatformNames.server` (and its platform detection), using a wider `other` platform instead.

## 0.9.1

* Use raw links for images in repository URLs.

* Move unconstrained version penalty from health score to maintenance.

* Move platform conflict penalty from health score to maintenance.

* Sort maintenance suggestions in decreasing importance.

## 0.9.0+1

* Fix NPE when dependency has no constraint (e.g. git repo).

## 0.9.0

* Only direct unconstrained dependencies decrease the health score.

* Removed superfluous `pubspec.lock` validation.

* Recommend descriptions between 60 and 180 characters.

* Detect another license format

* Pass-through values of `analyzer_options.yaml` errors like `uri_has_not_been_generated`.

## 0.8.2

* Unblock platform classification on a new class of errors.

* Better messages in platform classification.

## 0.8.1

* Use Flutter-recommended analysis options when analyzer Flutter packages.

* **BREAKING BEHAVIOR**: Don't use `PUB_HOSTED_URL` for package downloads,
  as it has not worked out in practice. Instead, we've added a `--hosted-url`
  command line argument.

## 0.8.0

* `PackageAnalyzer.inspectPackage` added a named argument 
  `deleteTemporaryDirectory`. Setting this to `false` retains the
  directory and prints its location to the log. Useful for debugging.

* `Maintenance`
  * **BREAKING** `getMaintenanceScore` now takes an optional `age` parameter 
    replacing the previously required `publishDate` parameter.

  * Changed the meaning of version fields:
    * `isExperimentalVersion` now means pre-V1.
    * `isPreReleaseVersion` now means there is a pre-release flag
      like `-beta`, `-alpha`, etc.
  
  * **BREAKING** maintenance-related `Suggestion` entries as moved to `Maintenance.suggestions`

* **BREAKING** `Suggestion.file` is now `String` instead of `dynamic`.

* Detect the new format of native extensions.

* Unblock platform classification on a new class of errors.

* Use `PUB_HOSTED_URL` for package downloads.

## 0.7.3+1

* Allow more versions of `package:args`.

## 0.7.3

* Added `pana` as an executable.
  Enables `pub global activate pana`.

* Improved license detection: commented license files are now recognized.

## 0.7.2

* Handle more critical exceptions and report them with more details.

* The `Suggestion.bug` constructor had a breaking change – a required argument
  was added, but this is not intended for invocation by end-users.

## 0.7.1

* Add `SuggestionLevel.bug` and use it to record fatal errors with the tool.

## 0.7.0+1

* Fixed issue where analyzer and/or formatter were run on directories with no
  Dart files.

## 0.7.0

* **Breaking changes**

  * `Summary.sdkVersion` is now a `Version` instead of `String`.
  
  * `new PackageAnalyzer(...)` now takes a `DartSdk` instance instead of
    a `String`.

* `static Future<PackageAnalyzer> create(...)` was added to `PackageAnalyzer`.

* Added `logger` optional argument to `PackageAnalyzer.inspectPackage`.

## 0.6.2

* Allow platform classification for a small class of analysis errors.

## 0.6.1

* Don't count the absence of an `analysis_options.yaml` file against a package. 

## 0.6.0

* **Breaking changes**

  * Removed `ToolProblem` class.
  * Removed `Summary.toolProblems`, in favor of `Summary.suggestions`.

* Detect and store maintenance-related data in summary.

  * Scoring of tool problems moved from `Fitness` to `Maintenance`.

* Provide human-readable feedback and instructions on some of the issues
  we find during the analysis.

## 0.5.1

* Use a consistent 2 minute timeout for all processes.

* Classify platform as `nowhere` when part of analysis fails.

## 0.5.0

* **Breaking changes**

  * `License` renamed to `LicenseFile`
  * `Summary.license` -> `licenses`: we'll return multiple licenses
  * Removed `LicenseNames.missing`: empty List will indicate no license file

* Greatly expanded and improved license detection.

## 0.4.0

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

  * Refactored `Fitness`:
    * Renamed `total` -> `magnitude`
    * Removed `value`, using `shortcoming` instead (`value` = `magnitude - shortcoming;`)

  * Refactored `PubSummary`, renamed to `PkgResolution`
    * Moved `pubspec` -> `Summary`
    * Moved `pkgVersion` -> `Pubspec.version`
    * Moved `authors` -> `Pubspec.authors`
    * Merged `packageVersions` and `availableVersions` into `dependencies`
    * Renamed `Summary.pubSummary` -> `pkgResolution`

  * Refactored `platform`:
    * Renamed `PlatformFlags` -> `PlatformNames`
    * Removed most of the platform-related classes, using `DartPlatform` instead

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
