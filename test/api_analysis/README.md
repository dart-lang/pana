# Testing API Analysis

Two API Analysis features are tested:
* the ability to produce a *summary*
* the ability to perform *lower bound constraint analysis* and identify *issues*

To reduce boilerplate, each test is concisely encapsulated in a YAML file, which is then parsed and executed. In the context of the following document, `doc` will be used to refer to the YAML document corresponding to a test.

`doc['name']` is a string storing the name of the test (applies to both test formats).

## Summary tests

Summary tests are located in `testdata/summary` and are parsed and run by `package_summary_test.dart`.

### Description

A test package (with the name `test.package` and version `1.0.0`, which cannot be changed by tests) is created from the `.dart` files specified in `doc` (other mandatory files like `pubspec.yaml` and `.dart_tool/package_config.json` are generated automatically and do not have to be specified explicitly in the YAML document). A *summary* is then generated based on the public API of this test package and any *id*s are re-assigned to bring the resulting PackageShape to normal form. Finally, the JSON representation of the resulting PackageShape is compared to the expected result to determine whether the test passes.

### Example YAML test

This is a passing test which demonstrates the syntax of a summary test. Note that this test does not demonstrate all the possible capabilities of a *package summary*.

```yaml
# The name of the test, as shown in Dart's test runner.
name: The summary should include top-level functions.
# The expected JSON form of the public API summary of the test package. This must be an exact match of the actual generated summary if the test is to pass.
summary: |-
  {
    "name": "test.package",
    "version": "1.0.0",
    "libraries": [
      {
        "uri": "package:test.package/a.dart",
        "exportedGetters": [],
        "exportedSetters": [],
        "exportedFunctions": [
          0
        ],
        "exportedClasses": [],
        "exportedExtensions": [],
        "exportedTypedefs": []
      },
      {
        "uri": "package:test.package/b.dart",
        "exportedGetters": [],
        "exportedSetters": [],
        "exportedFunctions": [
          1
        ],
        "exportedClasses": [],
        "exportedExtensions": [],
        "exportedTypedefs": []
      }
    ],
    "getters": [],
    "setters": [],
    "functions": [
      {
        "id": 0,
        "name": "f"
      },
      {
        "id": 1,
        "name": "g"
      }
    ],
    "classes": [],
    "extensions": [],
    "typedefs": []
  }
# The files comprising the test package, except `pubspec.yaml` and `.dart_tool/package_config.json` which are generated automatically.
# An empty array is also allowed, representing a package with no .dart library files.
# The values of the fields .package[].path must all be unique, and each one must be a relative path from the test package root.
package:
  - # The path of this .dart library.
    path: lib/a.dart
    # The content of this .dart library.
    content: void f() {}
  - path: lib/b.dart
    # Multi-line content is allowed.
    content: |
      void g() {}
      // This private top-level function should not be included in the summary.
      void _privateFunction() {}
  - path: lib/src/h.dart
    content: |
      // This top-level function is in a private library file, so it should not be included in the summary.
      void h() {}
```

## Lower bound constraint tests

Lower bound constraint tests are located in `testdata/lower_bound_constraint_issues` and are parsed and run by `lower_bound_constraint_issues_test.dart`.

### Description

A single target package is created from the `.dart` files specified in `doc` (other mandatory files like `pubspec.yaml` and `.dart_tool/package_config.json` are created automatically and do not have to be specified explicitly in the YAML document). This target package can specify its dependencies (a name and version constraint is required for each dependency). Similarly, any number of dependency packages may be created in the same way (with `pubspec.yaml` and `.dart_tool/package_config.json` omitted). The name and version must be specified for each of the dependency packages. The target package must only depend of packages which are specified as dependency packages.

Lower bound constraint analysis is executed on the target package, and the list of issues is verified against a list of regular expressions. The lists much have the same length and each regular expression should match an issue if the test is to pass.

### Example YAML test

This is a passing test which demonstrates the syntax of a lower bound constraint test. Note that this test does not demonstrate all the *issues* which can be identified by *lower bound constraint analysis*.

```yaml
# The name of the test, as shown in Dart's test runner.
name: Missing top-level functions should be detected
# The package releases available for the test package to depend on.
# No two releases can have an identical name and version.
packages:
  - # The name of the package in this release.
    name: foo
    # The version of the package in this release.
    version: 1.0.0
    # The files comprising this release.
    # This uses identical syntax as .package in the summary YAML test example.
    package:
      - path: lib/foo.dart
        content: g() {}
  - name: foo
    version: 1.1.0
    package:
      - path: lib/foo.dart
        content: |
          // A new top-level function f is introduced, breaking the public API of the package foo.
          void f() {}
          void g() {}
# The package to be tested for issues.
target:
  # The dependencies of the target package.
  # This array uses a similar format as the pubspec to specify dependencies and constraints.
  # The target package must only depend on package releases specified in .packages .
  dependencies:
    - name: foo
      # The version constraint itself is not important, but it is typically chosen to match two available releases, one of which is installed as a dependency of the target, and the other is allowed but may have a different public API. 
      version: ^1.0.0
  # The files comprising the target package.
  # This uses identical syntax as .package in the summary YAML test example.
  package:
    - path: lib/main.dart
      content: |
        import 'package:foo/foo.dart';
        void main() {
          f();
          g();
        }
# Regular expressions corresponding to he issues that are expected to be found.
# The number of expected issues must match the number of identified issues, and each regular expression corresponding to an expected issue must match exactly one string representation of an identified issue.
# An empty array is also allowed, where no issues are expected to be found.
issues:
  - 'identifier: f,'
```
