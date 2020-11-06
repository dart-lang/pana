// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:test/test.dart';

import 'package:pana/src/model.dart';

void main() {
  group('Report', () {
    test('join section with no match', () {
      final report = Report(sections: [
        ReportSection(
          id: 'a',
          title: 'a',
          grantedPoints: 5,
          maxPoints: 5,
          summary: 'something',
          status: ReportStatus.partial,
        ),
      ]);

      final nr = report.joinSection(ReportSection(
        id: 'b',
        title: 'b',
        grantedPoints: 10,
        maxPoints: 10,
        summary: 'other',
        status: ReportStatus.passed,
      ));

      expect(nr.toJson(), {
        'sections': [
          {
            'id': 'a',
            'title': 'a',
            'grantedPoints': 5,
            'maxPoints': 5,
            'summary': 'something',
            'status': 'partial'
          },
          {
            'id': 'b',
            'title': 'b',
            'grantedPoints': 10,
            'maxPoints': 10,
            'summary': 'other',
            'status': 'passed',
          },
        ]
      });
    });

    test('join with match', () {
      final report = Report(sections: [
        ReportSection(
          id: 'a',
          title: 'a',
          grantedPoints: 5,
          maxPoints: 5,
          summary: 'something\n',
          status: ReportStatus.partial,
        ),
        ReportSection(
          id: 'b',
          title: 'b',
          grantedPoints: 6,
          maxPoints: 10,
          summary: 'other',
          status: ReportStatus.passed,
        ),
      ]);

      final nr = report.joinSection(ReportSection(
        id: 'a',
        title: 'a',
        grantedPoints: 3,
        maxPoints: 7,
        summary: '\nanother thing\n',
        status: ReportStatus.failed,
      ));

      expect(
        nr.toJson(),
        {
          'sections': [
            {
              'id': 'a',
              'title': 'a',
              'grantedPoints': 8,
              'maxPoints': 12,
              'summary': 'something\n\nanother thing',
              'status': 'failed'
            },
            {
              'id': 'b',
              'title': 'b',
              'grantedPoints': 6,
              'maxPoints': 10,
              'summary': 'other',
              'status': 'passed',
            },
          ]
        },
      );
    });
  });
}
