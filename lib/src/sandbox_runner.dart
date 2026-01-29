// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'tool/run_constrained.dart';

/// Provides an interface to wrap an optional sandbox-runner script.
class SandboxRunner {
  /// When a sandbox environment is present, this identifies the executable path
  /// which will be used to prepend subprocess calls.
  final String? _executable;

  SandboxRunner(this._executable);

  /// Runs the [arguments] with the sandbox runner script.
  ///
  /// The script is expected to mount the following paths into the sandbox
  /// environment (read-only, unless otherwise specified):
  /// - The SDKs and binaries (webp) required by pana.
  /// - The directory identified by `XDG_CONFIG_HOME`.
  /// - The directory identified by `PUB_CACHE`.
  /// - The current working directory / package directory.
  /// - The directory identified by `SANDBOX_OUTPUT` (if present, is writable).
  ///
  /// The script will use its command line arguments to pass-through execution inside the sandbox.
  ///
  /// The script will pass-through the following environment variables inside the sandbox:
  /// - `CI`
  /// - `NO_COLOR`
  /// - `PATH`
  /// - `XDG_CONFIG_HOME`
  /// - `FLUTTER_ROOT`
  /// - `PUB_ENVIRONMENT`
  /// - `PUB_HOSTED_URL`
  ///
  /// The script will restrict network access, unless
  /// `SANDBOX_NETWORK_ENABLED=true` is specified.
  Future<PanaProcessResult> runSandboxed(
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
    bool throwOnError = false,
    String? outputFolder,
    List<String>? outputFolders,
    bool needsNetwork = false,
    bool writableConfigHome = false,
    bool writableCurrentDir = false,
    bool writablePubCacheDir = false,
    int? maxOutputBytes,
  }) async {
    environment ??= const <String, String>{};
    final allOutputFolders = <String>{
      ?outputFolder,
      ...?outputFolders,
      ?(writableConfigHome ? environment['XDG_CONFIG_HOME'] : null),
      ?(writablePubCacheDir ? environment['PUB_CACHE'] : null),
      ?(writableCurrentDir ? workingDirectory : null),
    };
    return await runConstrained(
      [?_executable, ...arguments],
      workingDirectory: workingDirectory,
      environment: {
        ...environment,
        if (allOutputFolders.isNotEmpty)
          'SANDBOX_OUTPUT': allOutputFolders.join(':'),
        if (needsNetwork) 'SANDBOX_NETWORK_ENABLED': 'true',
      },
      timeout: timeout,
      throwOnError: throwOnError,
      maxOutputBytes: maxOutputBytes,
    );
  }
}
