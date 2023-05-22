// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:tar/tar.dart';
import 'package:test/test.dart';
import 'package:test_descriptor/test_descriptor.dart' as d;

/// The current global [PackageServer].
PackageServer? get globalPackageServer => _globalPackageServer;
PackageServer? _globalPackageServer;

/// Creates an HTTP server that replicates the structure of pub.dartlang.org.
///
/// Calls [callback] with a [PackageServerBuilder] that's used to specify
/// which packages to serve.
Future servePackages([void Function(PackageServerBuilder?)? callback]) async {
  _globalPackageServer = await PackageServer.start(callback ?? (_) {});

  addTearDown(() {
    _globalPackageServer = null;
  });
}

/// Like [servePackages], but instead creates an empty server with no packages
/// registered.
///
/// This will always replace a previous server.
Future serveNoPackages() => servePackages((_) {});

class PackageServer {
  /// The underlying server.
  final shelf.Server _server;

  /// A future that will complete to the port used for the server.
  int get port => _server.url.port;

  /// The list of paths that have been requested from this server.
  final requestedPaths = <String>[];

  /// The base directory descriptor of the directories served by `this`.
  final d.DirectoryDescriptor _baseDir;

  /// The descriptors served by this server.
  ///
  /// This can safely be modified between requests.
  List<d.Descriptor> get contents => _baseDir.contents;

  /// Handlers for requests not easily described as files.
  final Map<Pattern, shelf.Handler> extraHandlers = {};

  String get url => 'http://localhost:$port';

  /// Creates an HTTP server to serve [contents] as static files.
  ///
  /// This server exists only for the duration of the pub run. Subsequent calls
  /// to [serve()] replace the previous server.
  static Future<PackageServer> start(
      void Function(PackageServerBuilder?) callback) async {
    final result =
        PackageServer._(await shelf_io.IOServer.bind('localhost', 0));
    result.add(callback);
    return result;
  }

  /// From now on, serve errors on all requests.
  void serveErrors() {
    extraHandlers[RegExp('.*')] = (request) {
      fail('The HTTP server received an unexpected request:\n'
          '${request.method} ${request.requestedUri}');
    };
  }

  PackageServer._(this._server) : _baseDir = d.dir('serve-dir', []) {
    _builder = PackageServerBuilder._(this);

    /// Creates an HTTP server
    contents
      ..add(d.dir('api', [_servedApiPackageDir]))
      ..add(_servedPackageDir);
    _server.mount((request) async {
      final pathWithInitialSlash = '/${request.url.path}';
      final key = extraHandlers.keys.firstWhereOrNull((pattern) {
        final match = pattern.matchAsPrefix(pathWithInitialSlash);
        return match != null && match.end == pathWithInitialSlash.length;
      });
      if (key != null) return extraHandlers[key]!(request);

      var path = p.posix.fromUri(request.url.path);
      requestedPaths.add(path);

      try {
        final stream = _baseDir.load(path);
        return shelf.Response.ok(stream);
      } catch (_) {
        return shelf.Response.notFound('File "$path" not found.');
      }
    });
    addTearDown(_server.close);
  }

  /// Closes this server.
  Future close() => _server.close();

  /// The [d.DirectoryDescriptor] describing the server layout of
  /// `/api/packages` on the test server.
  ///
  /// This contains metadata for packages that are being served via
  /// [servePackages].
  final _servedApiPackageDir = d.dir('packages', []);

  /// The [d.DirectoryDescriptor] describing the server layout of `/packages` on
  /// the test server.
  ///
  /// This contains the tarballs for packages that are being served via
  /// [servePackages].
  final _servedPackageDir = d.dir('packages', []);

  /// The current [PackageServerBuilder] that a user uses to specify which
  /// package to serve.
  ///
  /// This is preserved so that additional packages can be added.
  PackageServerBuilder? _builder;

  /// Add to the current set of packages that are being served.
  void add(void Function(PackageServerBuilder?) callback) {
    callback(_builder);

    _servedApiPackageDir.contents.clear();
    _servedPackageDir.contents.clear();

    _builder!._packages.forEach((name, package) {
      _servedApiPackageDir.contents.addAll([
        d.file(
            name,
            jsonEncode({
              'name': name,
              'uploaders': ['example@google.com'],
              'versions': package.versions
                  .map((version) => _packageVersionApiMap(url, version))
                  .toList(),
              if (package.isDiscontinued) 'isDiscontinued': true,
              if (package.discontinuedReplacementText != null)
                'replacedBy': package.discontinuedReplacementText,
            })),
      ]);

      _servedPackageDir.contents.add(d.dir(name, [
        d.dir(
            'versions',
            package.versions.map((version) => TarFileDescriptor(
                '${version.version}.tar.gz', version.contents)))
      ]));
    });
  }
}

/// Returns a Map in the format used by the pub.dartlang.org API to represent a
/// package version.
Map _packageVersionApiMap(String hostedUrl, _ServedPackageVersion package) {
  final pubspec = package.pubspec;
  final name = pubspec['name'];
  final version = pubspec['version'];
  final map = {
    'pubspec': pubspec,
    'version': version,
    'archive_url': '$hostedUrl/packages/$name/versions/$version.tar.gz',
    'published': (package.published ?? DateTime.now()).toIso8601String(),
  };

  return map;
}

/// A builder for specifying which packages should be served by [servePackages].
class PackageServerBuilder {
  /// A map from package names to the concrete packages to serve.
  final _packages = <String, _ServedPackage>{};

  /// The package server that this builder is associated with.
  final PackageServer _server;

  /// The URL for the server that this builder is associated with.
  String get serverUrl => _server.url;

  PackageServerBuilder._(this._server);

  /// Specifies that a package named [name] with [version] should be served.
  ///
  /// If [deps] is passed, it's used as the "dependencies" field of the pubspec.
  /// If [pubspec] is passed, it's used as the rest of the pubspec.
  ///
  /// If [contents] is passed, it's used as the contents of the package. By
  /// default, a package just contains a dummy lib directory.
  void serve(String name, String version,
      {Map<String, dynamic>? deps,
      Map<String, dynamic>? pubspec,
      Map<String, String>? versionData,
      Iterable<d.Descriptor>? contents,
      DateTime? published}) {
    var pubspecFields = <String, dynamic>{
      'name': name,
      'version': version,
      'environment': {'sdk': '>=2.12.0 <4.0.0'}
    };
    if (pubspec != null) pubspecFields.addAll(pubspec);
    if (deps != null) pubspecFields['dependencies'] = deps;

    contents ??= [libDir(name, '$name $version')];

    var package = _packages.putIfAbsent(name, _ServedPackage.new);
    package.versions.add(
      _ServedPackageVersion(
        pubspecFields,
        [
          d.file(
            'pubspec.yaml',
            const JsonEncoder.withIndent('  ').convert(pubspecFields),
          ),
          ...contents
        ],
        published: published,
      ),
    );
  }
}

/// Describes a directory named `lib` containing a single dart file named
/// `<name>.dart` that contains a line of Dart code.
d.Descriptor libDir(String name, [String? code]) {
  // Default to printing the name if no other code was given.
  code ??= name;
  return d.dir('lib', [d.file('$name.dart', 'main() => "$code";')]);
}

class _ServedPackage {
  List<_ServedPackageVersion> versions = [];
  bool isDiscontinued = false;
  String? discontinuedReplacementText;
}

/// A package that's intended to be served.
class _ServedPackageVersion {
  final Map pubspec;
  final List<d.Descriptor> contents;
  final DateTime? published;

  Version get version => Version.parse(pubspec['version'] as String);

  _ServedPackageVersion(this.pubspec, this.contents, {this.published});
}

/// Describes a tar file and its contents.
class TarFileDescriptor extends d.FileDescriptor {
  final List<d.Descriptor> contents;

  TarFileDescriptor(String name, Iterable<d.Descriptor> contents)
      : contents = contents.toList(),
        super.protected(name);

  Future<Iterable<TarEntry>> allFiles(d.Descriptor descriptor,
      [String path = '.']) async {
    if (descriptor is d.FileDescriptor) {
      final size =
          await descriptor.readAsBytes().fold<int>(0, (i, l) => i + l.length);
      return [
        TarEntry(
          TarHeader(
            name: '$path/${descriptor.name}',
            mode: 420,
            size: size,
            modified: DateTime.now(),
            userName: 'pub',
            groupName: 'pub',
          ),
          descriptor.readAsBytes(),
        )
      ];
    }

    final dir = descriptor as d.DirectoryDescriptor;
    return [
      for (final c in dir.contents) ...await allFiles(c, '$path/${dir.name}')
    ];
  }

  @override
  Stream<List<int>> readAsBytes() {
    return Stream.fromFutures(contents.map(allFiles))
        .expand((x) => x)
        .transform(tarWriter)
        .transform(gzip.encoder);
  }
}
