// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart' as http_retry;
import 'package:path/path.dart' as p;
import 'package:safe_url_check/safe_url_check.dart';
import 'package:tar/tar.dart';

import 'logging.dart';
import 'model.dart';
import 'version.dart';

/// Downloads [package] and unpacks it into [destination]
Future<void> downloadPackage(
  String package,
  String? version, {
  required String destination,
  String? pubHostedUrl,
}) async {
  pubHostedUrl ??= 'https://pub.dartlang.org';
  final pubHostedUri = Uri.parse(pubHostedUrl);
  final client = http_retry.RetryClient(
    http.Client(),
    when: (rs) => rs.statusCode >= 500,
  );
  try {
    // Find URI for the package archive
    final versionsUri = pubHostedUri.replace(
        path: p.join(pubHostedUri.path, '/api/packages/$package'));
    final versionsRs = await client.get(versionsUri);
    if (versionsRs.statusCode != 200) {
      throw Exception(
          'Unable to access URL: "$versionsUri" (status code: ${versionsRs.statusCode}).');
    }
    final versionsJson = json.decode(versionsRs.body);
    if (version == null) {
      version = versionsJson['latest']['version'] as String;
      log.fine('Latest version is: $version');
    }

    final data = (versionsJson['versions'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((e) => e['version'] == version);
    final archiveUrl = data['archive_url'] as String;

    var packageUri = Uri.parse(archiveUrl);
    if (!packageUri.hasScheme) {
      packageUri =
          pubHostedUri.replace(path: p.join(pubHostedUri.path, archiveUrl));
    }
    log.info('Downloading package $package $version from $packageUri');

    final rs = await client.get(packageUri);
    if (rs.statusCode != 200) {
      throw Exception(
          'Unable to access URL: "$packageUri" (status code: ${rs.statusCode}).');
    }
    await _extractTarGz(Stream.value(rs.bodyBytes), destination);
  } catch (e, st) {
    log.warning('Unable to download $package $version', e, st);
    rethrow;
  } finally {
    client.close();
  }
}

/// Returns an URL that is likely the downloadable URL of the given path.
@Deprecated('The method will be removed in a future release.')
String? getRepositoryUrl(
  String? repository,
  String relativePath, {
  String? branch,
}) {
  if (repository == null) return null;
  final url = Repository.tryParseUrl(repository);
  return url?.resolveUrl(relativePath, branch: branch);
}

/// The URL's parsed and queried status.
class UrlStatus {
  /// Whether the URL can be parsed and is valid.
  final bool isInvalid;

  /// Whether the URL uses HTTPS.
  final bool isSecure;

  /// Whether the URL exists and responds with an OK status code.
  final bool exists;

  UrlStatus({
    required this.isInvalid,
    required this.isSecure,
    required this.exists,
  });

  UrlStatus.invalid()
      : isInvalid = true,
        isSecure = false,
        exists = false;

  /// Returns a brief problem code that can be displayed when linking to it.
  /// Returns `null` when URL has no problem.
  String? getProblemCode() {
    if (isInvalid) return UrlProblemCodes.invalid;
    if (!isSecure) return UrlProblemCodes.insecure;
    if (!exists) return UrlProblemCodes.missing;
    return null;
  }
}

/// Checks if an URL is valid and accessible.
class UrlChecker {
  /// Returns `true` if the [uri] exists,
  /// `false` if getting the page encountered problems.
  ///
  /// A cached [UrlChecker] implementation should override this method,
  /// wrap it in a cached callback, still invoking it via `super.checkUrlExists()`.
  Future<bool> checkUrlExists(Uri uri) async {
    return await safeUrlCheck(uri,
        userAgent: 'pana/$packageVersion (https://pub.dev/packages/pana)');
  }

  /// Check the status of the URL, using validity checks, cache and
  /// safe URL checks with limited number of redirects.
  Future<UrlStatus> checkStatus(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return UrlStatus.invalid();
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return UrlStatus.invalid();
    }
    // The safe URL check will verify if the resolved IP of the host name
    // seems to be valid (e.g. not an a local loopback, multicast or private network).
    final exists = await checkUrlExists(uri);
    return UrlStatus(
      isInvalid: false,
      isSecure: uri.scheme == 'https',
      exists: exists,
    );
  }
}

/// Extracts a `.tar.gz` file from [tarball] to [destination].
Future _extractTarGz(Stream<List<int>> tarball, String destination) async {
  log.fine('Extracting .tar.gz stream to $destination.');
  final reader = TarReader(tarball.transform(gzip.decoder));
  while (await reader.moveNext()) {
    final entry = reader.current;
    final path = p.join(destination, entry.name);
    if (!p.isWithin(destination, path)) {
      throw ArgumentError('"${entry.name}" is outside of the archive.');
    }
    if (entry.type == TypeFlag.dir) {
      continue;
    }
    final dir = File(path).parent;
    await dir.create(recursive: true);
    if (entry.header.linkName != null) {
      final target = p.normalize(p.join(dir.path, entry.header.linkName));
      if (p.isWithin(destination, target)) {
        final link = Link(path);
        if (!link.existsSync()) {
          await link.create(target);
        }
      } else {
        log.info('Link from "$path" points outside of the archive: "$target".');
        // Note to self: do not create links going outside the package, this is not safe!
      }
    } else {
      await entry.contents.pipe(File(path).openWrite());
    }
  }
}
