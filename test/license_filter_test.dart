// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:pana/src/license_detection/license.dart';
import 'package:pana/src/license_detection/tokenizer.dart';
import 'package:test/test.dart';

import 'package:pana/src/license_detection/primary_filter.dart';

void main() {
  group('License Filter Tests:', () {
    test('Test token similarity', () {
      var text1 = 'Some tokens to test';
      var text2 = 'some tokens to test';

      final license = License.parse('', text1);
      var tokens2 = tokenize(text2);

      expect(
          tokenSimilarity(license.occurences, generateFrequencyTable(tokens2)),
          1);

      tokens2 = tokenize('some tokens are different');
      expect(
          tokenSimilarity(license.occurences, generateFrequencyTable(tokens2)),
          0.5);

      tokens2 = tokenize('one tokens match');
      expect(
          tokenSimilarity(license.occurences, generateFrequencyTable(tokens2)),
          1 / 3);

      tokens2 = tokenize('');
      expect(
          tokenSimilarity(license.occurences, generateFrequencyTable(tokens2)),
          0);
    });

    test('Known licenses primary filtering', () {
      final input = '''BSD 2-Clause License

Copyright (c) [year], [fullname]
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''';
      final unknownLicense = License.parse('', input);
      final knownLicenses =
          loadLicensesFromDirectories(['test/license_test_assets']);

      final possibleLicenses = filter(unknownLicense.occurences, knownLicenses);
      const possibleLicenseNames = [
        'bsd_2_clause',
        'bsd_2_clause_in_comments',
        'bsd_3_clause'
      ];
      expect(possibleLicenses.length, 3);

      for (var i = 0; i < 3; i++) {
        expect(possibleLicenses[i].identifier, possibleLicenseNames[i]);
      }
    });
  });
}
