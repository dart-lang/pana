# API Analysis

*API analysis* is a project undertaken in the summer of 2022 as part of the Google Summer of Code program.

It is often challenging to make backwards-compatible changes to an existing package, which is already depended on by other packages and applications. When developers make breaking changes to a package, they risk breaking other people's dependent code. But this problem can also apply in reverse: when a dependent package (the *target package*) updates their code, relying on a breaking change made by a dependency, it is easy to forget to update the version constraint associated with this dependency, allowing releases of the dependency before the breaking change.

This latter problem will be referred to as a *lower bound constraint issue* and *API analysis* aims to identify cases of these *issue* across the Dart ecosystem. Because it is difficult to identify what is and isn't a breaking change, the criterion for a breaking change for the purposes of *API analysis* is the removal/renaming of a public symbol. As the version solving algorithm used by pub favours more recent versions, *issues*  will likely not lead to unexpected behaviour when developing the *target package*, but any packages which themselves have a dependency on the *target* may introduce tighter dependency constraints, leading to the possibility that symbols required by the *target package* dependency are not found and the package fails to compile. The solution to resolve an *issue* is always to bump up the lower bound version constraint of a dependency of the *target* which provides the symbol in question. In this way, any packages depending on *target* and imposing tighter version constraints will fail version solving (instead of failing to compile), which is closer to the real cause of the problem - incompatible version constraints on a shared dependency (with *target* as one of the dependent packages).

## Package summary, the *Shape model

Before *lower bound constraint analysis* can be performed, it is necessary to determine which symbols are available in the public API of a package.

For the purposes of API analysis, the public API of a package is summarized as a `PackageShape` object, which itself contains various other `*Shape` objects descriving the members of the package, such as top-level getters/setters, functions, classes, extensions and typedefs. The members of each class and extension are also recorded. Note that in place of properties, the `*Shape` objects summarise getters and setters discretely.

## Definitions

### target (package)

### (lower bound constraint) issue

The usage of a symbol defined in a dependency 

### lower bound constraint analysis

### (package) summary

## Related

https://github.com/dart-lang/dartdoc

https://github.com/google/dart-shapeshift
