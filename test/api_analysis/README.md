# Testing API Analysis

Two API Analysis features are tested:
* the ability to produce a *summary*
* the ability to perform *lower bound constraint analysis* and identify *issues*

To reduce boilerplate, each test is concisely encapsulated in a YAML file, which is then parsed and executed. In the context of the following document, `doc` will be used to refer to the YAML document corresponding to a test.

`doc['name']` is a string storing the name of the test (applies to both test formats).

## Summary tests

Summary tests are located in `testdata/summary` and are parsed and run by `package_summary_test.dart`.

### Description

A test package is created from the `.dart` files specified in `doc` (other mandatory files like `pubspec.yaml` and `.dart_tool/package_config.json` are created automatically and do not have to be specified explicitly in the YAML document). A *summary* is then generated based on the public API of this test package and any *id*s are re-assigned to bring the resulting PackageShape to normal form. Finally, the JSON representation of the resulting PackageShape is compared to the expected result to determine whether the test passes.

### YAML schema

`doc['package']` is an array storing all the files comprising the test package, omitting `pubspec.yaml` and `.dart_tool/package_config.json`.
`doc['package'][i]['path']` is a string storing the path of the `i`th file, typically of the form `'lib/*.dart'`.
`doc['package'][i]['content']` is a string storing the contents of the `i`th file.

## Lower bound constraint tests

Lower bound constraint tests are located in `testdata/lower_bound_constraint_issues` and are parsed and run by `lower_bound_constraint_issues_test.dart`.

### Description

A single target package is created from the `.dart` files specified in `doc` (other mandatory files like `pubspec.yaml` and `.dart_tool/package_config.json` are created automatically and do not have to be specified explicitly in the YAML document). This target package can specify its dependencies (a name and version constraint is required for each dependency). Similarly, any number of dependency packages may be created in the same way (with `pubspec.yaml` and `.dart_tool/package_config.json` omitted). The name and version must be specified for each of the dependency packages. The target package must only depend of packages which are specified as dependency packages.

Lower bound constraint analysis is executed on the target package, and the list of issues is verified against a list of regular expressions. The lists much have the same length and each regular expression should match an issue if the test is to pass.

### YAML schema

`doc['target']['package']` is an array storing all the files comprising the target package, omitting `pubspec.yaml` and `.dart_tool/package_config.json`.
`doc['target']['package'][i]['path']` is a string storing the path of the `i`th file of the target package, typically of the form `'lib/*.dart'`.
`doc['target']['package'][i]['content']` is a string storing the contents of the `i`th file of the target package.
`doc['target']['dependencies']` is an array storing the dependencies/version constraints of the target package.
`doc['target']['dependencies'][j]['name']` is a string storing the name of the `j`th dependency of the target package.
`doc['target']['dependencies'][j]['version']` is a string storing the version constraint associated with the `j`th dependency of the target package, in the notation that it would be specified in the pubspec.
`doc['packages']` is an array storing all the dependency package releases that the target package can depend on.
`doc['packages'][k]['name']` is a string storing the name of the `k`th package release.
`doc['packages'][k]['version']` is a string storing the version of the `k`th package release.
`doc['packages'][k]['package']` is an array storing all the files comprising the `k`th package release, omitting `pubspec.yaml` and `.dart_tool/package_config.json`
`doc['packages'][k]['package'][l]['path']` is a string storing the path of the `l`th file of the `k`th package release, typically of the form `'lib/*.dart'`.
`doc['packages'][k]['package'][l]['content']` is a string storing the contents of the `l`th file of the `k`th package release.

