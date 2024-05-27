## 5/30 Follow Dart file conventions

### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
The package description is too short.
</summary>

Add more detail to the `description` field of `pubspec.yaml`. Use 60 to 180 characters to describe the package, what it does, and its target use case.
</details>

### [x] 0/5 points: Provide a valid `README.md`

<details>
<summary>
Links in `README.md` should be secure. 1 link is insecure.
</summary>

`README.md:42:35`

```
   ╷
42 │ <p>This library is licensed under <a href="http://www.opensource.org/licenses/mit-license.php">MIT License</a>.</p>
   │                                   ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
   ╵
```

Use `https` URLs instead.
</details>

### [*] 5/5 points: Provide a valid `CHANGELOG.md`


### [x] 0/10 points: Use an OSI-approved license

<details>
<summary>
No license was recognized.
</summary>

Consider using an [OSI-approved license](https://opensource.org/licenses) in the `LICENSE` file to make it more accessible to the community.
</details>

## 0/10 Provide documentation

### [x] 0/10 points: Package has an example

<details>
<summary>
No example found.
</summary>

See [package layout](https://dart.dev/tools/pub/package-layout#examples) guidelines on how to add an example.
</details>

## 0/20 Platform support

### [x] 0/20 points: Platform support detection failed

<details>
<summary>
Could not determine supported platforms as package resolution failed.
</summary>

Run `dart pub get` for more information.
</details>

## 0/50 Pass static analysis

### [x] 0/50 points: code has no errors, warnings, lints, or formatting issues

* Running `dart pub outdated` failed with the following output:

```
The lower bound of "sdk: '>=0.8.10 <3.0.0'" must be 2.12.0'
or higher to enable null safety.
```


## 0/40 Support up-to-date dependencies

### [x] 0/10 points: All of the package dependencies are supported in the latest version

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}. Cannot run `dart pub outdated`.
</summary>

`pubspec.yaml:10:10`

```
   ╷
10 │     sdk: '>=0.8.10 <3.0.0'
   │          ^^^^^^^^^^^^^^^^^
   ╵
```

</details>

### [x] 0/10 points: Package supports latest stable Dart and Flutter SDKs

<details>
<summary>
Sdk constraint doesn't support current Dart version {{sdk-version}}.
</summary>

`pubspec.yaml:10:10`

```
   ╷
10 │     sdk: '>=0.8.10 <3.0.0'
   │          ^^^^^^^^^^^^^^^^^
   ╵
```

Try widening the upper boundary of the constraint.
</details>

### [x] 0/20 points: Compatible with dependency constraint lower bounds

* `dart pub downgrade` failed with:

```
OUT:
Resolving dependencies...
ERR:
The lower bound of "sdk: '>=0.8.10 <3.0.0'" must be 2.12.0'
or higher to enable null safety.

The current Dart SDK (3.4.0) only supports null safety.

For details, see https://dart.dev/null-safety
```

Run `dart pub downgrade` and then `dart analyze` to reproduce the above problem.

You may run `dart pub upgrade --tighten` to update your dependency constraints, see [dart.dev/go/downgrade-testing](https://dart.dev/go/downgrade-testing) for details.