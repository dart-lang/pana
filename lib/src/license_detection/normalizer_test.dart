import 'package:test/test.dart';

import 'normalizer.dart';

void main() {
  group('Normalizer tests', () {
    test('SPDX guideline 4.1.1', () {
      expect(normalize('ALL UPPERCASE'), 'all uppercase');
      expect(normalize('Hello!'), 'hello!');
      expect(normalize('QWERTYUIOPASDFGHJKLZXCVBNM'),'qwertyuiopasdfghjklzxcvbnm');
    });

    test('SPDX guideline 3.1.1', () {
      expect(
          normalize(
              'there\u2008are\u00A0different\u2003whitespaces\u2006\u2007'),
          'there are different whitespaces ');

      expect(normalize('Vanish\n              spaces'), 'vanish\n spaces');
    });

    test('Carriage return and nel', () {
      expect(normalize('Carriage Return\rNew Line\n NEL\u0085'),
          'carriage return\nnew line\n nel\n');
    });

    test('SPDX guideline 5', () {
      expect(normalize('change–—﹘﹣－‒⁃⁻⎯─⏤different hiphens'),
          'change-----------different hiphens');

      expect(normalize('❝different❞ 〝quotations〞 ❛❜'),
          "'different' 'quotations' ''");
    });

    test('SPDX guideline 8.1.1', () {
      expect(
          normalize(
              'license and licence are acknowledgment centre of copyright holder'),
          'license and license are acknowledgement center of copyright owner');

      expect(normalize('initialise labor recognise fulfilment'),
          'initialize labour recognize fulfilment');
    });

    test('SPDX guideline 2.1.4 and 9.1.1', () {
      expect(normalize('copyright © year <copyright holder>'), '');
      expect(
          normalize('MIT license\n//copyright (c) 2014-2020'), 'mit license\n');
      expect(normalize('// Version 2.4, 2019\nSome extra text'),
          '\nsome extra text');
    });

    test('Complex case', () {
      final str = '''MIT No Attribution
Version 1.1, 2019
// Copyright <YEAR> <COPYRIGHT HOLDER>
All rights reserved
Permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the ❝Software❝), to deal in the Software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so.''';

      final normalised = '''mit no attribution



permission is hereby granted, free of charge, to any person obtaining a copy of this
software and associated documentation files (the 'software'), to deal in the software
without restriction, including without limitation the rights to use, copy, modify,
merge, publish, distribute, sublicense, and/or sell copies of the software, and to
permit persons to whom the software is furnished to do so.''';

      expect(normalize(str), normalised);
    });
  });
}
