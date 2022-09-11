# API Analysis

Refer to the [introductory blog post](https://arseny.uk/posts/gsoc2022/) before reading this document.

## Running API analysis

Three CLI subcommands are provided. Run `dart pub global activate --source git https://github.com/dart-lang/pana` to make them globally available and run them with `dart pub global run pana:api_analysis subcommand`.

### `summary`

```
Displays a summary of the public API of a package.
Usage: api_analysis summary package_path
```

This command writes a JSON *summary* of the package at `package_path`, which must point to the root directory of a package, to standard output.

This package does not have to be published to pub.dev , and `package_path` can point to a directory in the [pub cache](https://dart.dev/tools/pub/glossary#system-cache).

### `lbcanalysis`

```
Performs lower bound analysis on a single package.
Usage: api_analysis lbcanalysis cache_path target_name
```

This command performs *lower bound constraint analysis* on the latest version of the package named `target_name`, which must be the name of a package published to pub.dev . If at least one *issue* is discovered, a report is written to standard output. Any warnings are written to standard error.

`cache_path` must point to a directory where http requests to `https://pub.dev/api/packages/PACKAGE_NAME` will be cached (where `PACKAGE_NAME` is the name of the *target* or that of one of its direct dependencies).

### `batchlbca`

```
Runs lower bound constraint analysis on many packages.
Usage: api_analysis batchlbca package_number process_number log_path cache_path
```

This command performs *lower bound constraint analysis* on a number of packages published to pub.dev .

A package is considered eligible if it satisfies the following requirements:
- The current version of the Dart SDK satisfies the SDK constraint of the package.
- The SDK constraint lower bound of the package is 2.12 or later, meaning it is [null safe](https://dart.dev/null-safety).
- The package is not marked as discontinued.
- There is at least one non-retracted version of the package.

`package_number` specifies the number of eligible packages to *analyse*.

If the number of packages provided by https://pub.dev/api/package-name-completion-data is greater than or equal to `package_number`, the first `package_number` eligible packages from this list are *analysed*.

Otherwise, the first `package_number` eligible packages from https://pub.dev/api/package-names are *analysed*. If `package_number` is strictly greater than the number of eligible packages from this list, all the eligible packages from the list are *analysed*.

*Analysis* consists of `process_number` concurrent child processes of the `lbcanalysis` command running in parallel. The standard output and standard error streams produced by these processes are saved as text files in the `log_path` directory. If a package takes over 10 minutes to analyse, the `lbcanalysis` process is killed.

`cache_path` must point to a directory where http requests to `https://pub.dev/api/packages/PACKAGE_NAME` will be cached, (where `PACKAGE_NAME` is the name of any eligible package). In an effort to make the results consistent (the parent `batchlbca` process can take several hours), this cache is populated before any child `lbcanalysis` processes are started.

## Hacking on API analysis

This directory (along with the CLI runner https://github.com/dart-lang/pana/blob/master/bin/api_analysis.dart ) contains the code for running API analysis.

The directory https://github.com/dart-lang/pana/blob/master/test/api_analysis containing tests and related documentation gives a great overview of the capabilities of API analysis.

## Definitions

### (lower bound constraint) issue

The scenario of a package specifying a wider range of allowed versions of a particular dependency than the range of versions which define the symbols required by the package from this dependency.

This typically requires the package to specify a dependency version constraint which spans a breaking change in the dependency's public API (allowing a package version before and after the breaking change took place). Specifying the wrong dependency constraint is a bug.

### target (package)

The package being analysed for *issues*.

### lower bound constraint analysis

The process of statically analyzing one or many *target packages* to find *issues*. 

### (package) summary

An overview of the public API of a package.
