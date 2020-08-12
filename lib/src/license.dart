// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library pana.license;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'download_utils.dart';
import 'maintenance.dart';
import 'model.dart';

Future<LicenseFile> detectLicenseInDir(String baseDir) async {
  for (final candidate in licenseFileNames) {
    final file = File(p.join(baseDir, candidate));
    if (!file.existsSync()) continue;
    return detectLicenseInFile(file, relativePath: candidate);
  }
  return null;
}

Future<String> getLicenseUrl(
    UrlChecker urlChecker, String baseUrl, LicenseFile license) async {
  if (baseUrl == null || baseUrl.isEmpty) {
    return null;
  }
  if (license == null || license.path == null || license.path.isEmpty) {
    return null;
  }
  final url = getRepositoryUrl(baseUrl, license.path);
  if (url == null) {
    return null;
  }
  final status = await urlChecker.checkStatus(url);
  if (status == UrlStatus.exists) {
    return url;
  } else {
    return null;
  }
}

Future<LicenseFile> detectLicenseInFile(File file,
    {String relativePath}) async {
  final content = utf8.decode(await file.readAsBytes(), allowMalformed: true);
  var license = detectLicenseInContent(content, relativePath: relativePath);
  return license ?? LicenseFile(relativePath, LicenseNames.unknown);
}

LicenseFile detectLicenseInContent(String originalContent,
    {String relativePath}) {
  var content = originalContent;
  if (content.startsWith('// ')) {
    content = content.split('\n').map((s) {
      return s.startsWith('// ') ? s.substring(3) : s;
    }).join('\n');
  }
  var stripped = _longTextPrepare(content);

  String version;
  var versionMatch = _version.firstMatch(stripped);
  if (versionMatch != null) {
    version = versionMatch.group(1);
    if (version.isNotEmpty && !version.contains('.')) {
      version += '.0';
    }
  }

  if (_mpl.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.MPL, version: version);
  }
  if (_agpl.hasMatch(stripped) && !_useWithAgpl.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.AGPL, version: version);
  }
  if (_apache.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.Apache, version: version);
  }
  if (_lgpl.hasMatch(stripped) && !_useLgplInstead.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.LGPL, version: version);
  }
  if (_gplLong.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.GPL, version: version);
  }
  if (_gplShort.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.GPL, version: version);
  }
  if (_mit.hasMatch(stripped) || _mitEmphasis.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.MIT, version: version);
  }
  if (_unlicense.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.Unlicense, version: version);
  }

  if (_bsdPreamble.hasMatch(stripped) && _bsdEmphasis.hasMatch(stripped)) {
    return LicenseFile(relativePath, LicenseNames.BSD);
  }

  return null;
}

final RegExp _whitespace = RegExp('\\s+');
final RegExp _extraCharacters = RegExp('\\"|\\\'|\\*');

final RegExp _agpl =
    RegExp('GNU AFFERO GENERAL PUBLIC LICENSE', caseSensitive: false);
final RegExp _useWithAgpl = RegExp(
    'Use with the GNU Affero General Public License',
    caseSensitive: false);
final RegExp _apache = RegExp(r'Apache License', caseSensitive: false);
final RegExp _gplLong = RegExp('GENERAL PUBLIC LICENSE', caseSensitive: false);
final RegExp _gplShort = RegExp('GNU GPL', caseSensitive: false);
final RegExp _lgpl =
    RegExp(r'GNU LESSER GENERAL PUBLIC LICENSE', caseSensitive: false);
final RegExp _useLgplInstead = RegExp(
    'use the GNU Lesser General Public License instead',
    caseSensitive: false);
final RegExp _mit = RegExp(r'(^|\s)MIT License', caseSensitive: false);
final RegExp _mpl = RegExp('Mozilla Public License', caseSensitive: false);
final RegExp _unlicense = RegExp(
    'This is free and unencumbered software released into the public domain',
    caseSensitive: true);
final RegExp _version = RegExp(r'Version (\d+(\.\d*)?)', caseSensitive: false);

final RegExp _bsdPreamble = RegExp(
    'Redistribution and use in source and binary forms, with or without '
    'modification, are permitted (\\(subject to the limitations in the disclaimer below\\) )?'
    'provided that the following conditions are met',
    caseSensitive: false);

final RegExp _bsdEmphasis = _longTextRegExp('''
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED.
''');

final RegExp _mitEmphasis = _longTextRegExp('''
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.''');

String _longTextPrepare(String text) =>
    text.replaceAll(_extraCharacters, ' ').replaceAll(_whitespace, ' ').trim();

RegExp _longTextRegExp(String text) =>
    RegExp(_longTextPrepare(text), caseSensitive: false);
