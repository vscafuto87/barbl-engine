import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:barbl_engine/src/generate/select_template.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _template(String id, int days, List<String> goals) => {
  'id': id,
  'split': 'upper_lower',
  'daysPerWeek': days,
  'goals': goals,
  'defaultSchedule': {'mon': 'lower_a'},
  'sessions': [
    {
      'id': 'lower_a',
      'name': {'it': 'Lower A', 'en': 'Lower A'},
      'focus': 'legs',
      'blocks': [
        {
          'type': 'single',
          'slots': [
            {
              'pattern': 'squat',
              'role': 'main',
              'candidates': ['squat'],
            },
          ],
        },
      ],
    },
  ],
};

KnowledgeBase _kb() => KnowledgeBase.fromJson(
  minimalBundle(
    templates: {
      't_4d': _template('t_4d', 4, ['muscle_gain']),
      't_3d': _template('t_3d', 3, ['both']),
    },
  ),
);

void main() {
  group('selectTemplate', () {
    test('4 giorni e muscle_gain scelgono il template a 4 giorni', () {
      final r = selectTemplate(testProfile(), _kb());
      expect(r, isA<Ok<KbTemplate>>());
      expect((r as Ok<KbTemplate>).value.id, 't_4d');
    });

    test('4 giorni e strength: NotCovered(goal)', () {
      final r = selectTemplate(testProfile(goal: 'strength'), _kb());
      expect(r, isA<Rejected<KbTemplate>>());
      final reason = (r as Rejected<KbTemplate>).reason;
      expect(reason.reason, NotCoveredReason.goal);
      expect(reason.detail, contains('strength'));
    });

    test('5 giorni: NotCovered(days)', () {
      final r = selectTemplate(testProfile(daysPerWeek: 5), _kb());
      expect(r, isA<Rejected<KbTemplate>>());
      final reason = (r as Rejected<KbTemplate>).reason;
      expect(reason.reason, NotCoveredReason.days);
      expect(reason.detail, contains('daysPerWeek=5'));
    });

    test('3 giorni e both scelgono il template a 3 giorni', () {
      final r = selectTemplate(
        testProfile(daysPerWeek: 3, goal: 'both'),
        _kb(),
      );
      expect((r as Ok<KbTemplate>).value.id, 't_3d');
    });
  });
}
