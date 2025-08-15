// Copyright (c) 2022, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../model.dart';
import '../third_party/spdx/licenses.dart';

import 'pana_tags.dart';

class LicenseTags {
  final List<License> licenses;
  final List<String> tags;
  LicenseTags(this.licenses, this.tags);

  late final isOnlyOsiApproved = tags.contains(PanaTags.licenseOsiApproved);
  late final wasDetected = !tags.contains(PanaTags.licenseUnknown);

  late final osiApprovedLicenses = licenses
      .where((l) => l.isOsiApproved)
      .toList();
  late final nonOsiApprovedLicenses = licenses
      .where((l) => !l.isOsiApproved)
      .toList();

  factory LicenseTags.fromLicenses(List<License> licenses) {
    final tags = <String>[];
    if (licenses.isNotEmpty) {
      tags.addAll(
        licenses
            .map((l) => 'license:${l.spdxIdentifier.toLowerCase()}')
            .toSet(),
      );
      if (licenses.every((l) => l.isFsfLibre)) {
        tags.add(PanaTags.licenceFsfLibre);
      }
      if (licenses.every((l) => l.isOsiApproved)) {
        tags.add(PanaTags.licenseOsiApproved);
      }
    } else {
      tags.add(PanaTags.licenseUnknown);
    }
    return LicenseTags(licenses, tags);
  }
}

extension LicenseExt on License {
  bool get isFsfLibre => fsfLibreLicenses.contains(spdxIdentifier);
  bool get isOsiApproved => osiApprovedLicenses.contains(spdxIdentifier);
}
