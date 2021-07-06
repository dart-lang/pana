// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/primary_filter.dart';

// Load corpus licenses.
final _licenses = loadLicensesFromDirectories(_directories);

// WIP: Returns a list of detected licenses whose
// confidence score is above a certain threshold.
List<LicenseMatch> detectLicense(String text) {
  final unknownLicense = License.parse('', text);

  final possibleLicenses = filter(unknownLicense.occurences, _licenses);
  for (var license in possibleLicenses) {
    print(license.identifier);
  }

  return <LicenseMatch>[];
}

const _directories = ['third_party/spdx/licenses'];
