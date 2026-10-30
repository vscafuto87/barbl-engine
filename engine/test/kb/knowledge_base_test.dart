import 'package:barbl_engine/barbl_engine.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';

void main() {
  group('KnowledgeBase.fromJson', () {
    test('legge un pacchetto minimo', () {
      final kb = KnowledgeBase.fromJson(minimalBundle());
      expect(kb.rulesVersion, '9.9.9');
      expect(kb.kbCommit, 'abc123');
      expect(kb.primaryWeight, 1.0);
      expect(kb.secondaryWeight, 0.5);
      expect(kb.exercises['squat']!.stepKg, 2.5);
      expect(kb.exercises['squat']!.secondaryMuscles, ['glutes']);
      final slot = kb
          .templates.single.sessions.single.blocks.single.slots.single;
      expect(slot.askLoad, true);
      expect(slot.repsOverride, isNull);
      expect(kb.prescriptions.single.roles['main']!.restLower, 180);
      expect(kb.prescriptions.single.minutesPerSet, 3);
      expect(kb.parameterGroups.keys, hasLength(3));
      expect(kb.parameterGroups['tired']!.ruleId, isNull);
      expect(kb.parameterGroups['mesocycle']!.engineConstraints, {'x': 1});
      expect(kb.rationales.single.everyExercise, true);
      expect(kb.principles['P-1']!.sources, ['s1']);
      expect(kb.sources['s1']!.tier, 1);
    });

    test('bundleFormat diverso da 1 lancia KbFormatException', () {
      final json = minimalBundle()..['bundleFormat'] = 2;
      expect(() => KnowledgeBase.fromJson(json), throwsA(isA<KbFormatException>()));
    });

    test('una chiave mancante lancia con il nome della chiave', () {
      final json = minimalBundle()..remove('exercises');
      expect(
        () => KnowledgeBase.fromJson(json),
        throwsA(
          isA<KbFormatException>().having(
            (e) => e.message,
            'message',
            contains('exercises'),
          ),
        ),
      );
    });

    test('un esercizio a corpo libero senza stepKg ha stepKg nullo', () {
      final json = minimalBundle();
      (json['exercises'] as Map)['push_up'] = {
        'id': 'push_up',
        'name': {'it': 'Piegamenti', 'en': 'Push-up'},
        'equipment': 'bodyweight',
        'requires': <Object?>[],
        'pattern': 'horizontal_push',
        'muscles': {'primary': 'chest'},
        'loading': {'whenLoadUnknown': 'manual'},
      };
      final kb = KnowledgeBase.fromJson(json);
      expect(kb.exercises['push_up']!.stepKg, isNull);
      expect(kb.exercises['push_up']!.secondaryMuscles, isEmpty);
    });

    test('stepKg intero diventa double', () {
      final json = minimalBundle();
      final ex = (json['exercises'] as Map)['squat'] as Map;
      (ex['loading'] as Map)['stepKg'] = 2;
      final kb = KnowledgeBase.fromJson(json);
      expect(kb.exercises['squat']!.stepKg, 2.0);
    });

    test('repsOverride e askLoad dello slot', () {
      final json = minimalBundle();
      final t = (json['templates'] as Map)['t1'] as Map;
      final sessions = t['sessions'] as List;
      final blocks = (sessions.single as Map)['blocks'] as List;
      final slot = ((blocks.single as Map)['slots'] as List).single as Map;
      slot['repsOverride'] = {'min': 6, 'max': 8};
      final kb = KnowledgeBase.fromJson(json);
      final read = kb.templates.single.sessions.single.blocks.single.slots.single;
      expect(read.repsOverride, (min: 6, max: 8));
      expect(read.askLoad, true);
    });

    test('il mesociclo conserva la lista delle settimane', () {
      final json = minimalBundle();
      final meso = (json['parameters'] as Map)['mesocycle'] as Map;
      meso['values'] = {
        'weeks': [
          {'number': 1, 'type': 'load', 'rirTarget': 3},
          {'number': 2, 'type': 'deload', 'rirTarget': 4},
        ],
      };
      final kb = KnowledgeBase.fromJson(json);
      final weeks = kb.parameterGroups['mesocycle']!.values['weeks'] as List;
      expect(weeks, hasLength(2));
      expect((weeks[1] as Map)['type'], 'deload');
    });

    test('un tipo sbagliato indica il percorso del campo', () {
      final json = minimalBundle();
      final ex = (json['exercises'] as Map)['squat'] as Map;
      (ex['loading'] as Map)['stepKg'] = 'due';
      expect(
        () => KnowledgeBase.fromJson(json),
        throwsA(
          isA<KbFormatException>().having(
            (e) => e.message,
            'message',
            contains('stepKg'),
          ),
        ),
      );
    });

    group('invarianti della generazione', () {
      Matcher rejects(String part) => throwsA(
        isA<KbFormatException>().having(
          (e) => e.message,
          'message',
          contains(part),
        ),
      );

      test('un focus non gestito è rifiutato', () {
        final json = minimalBundle();
        final tpl = (json['templates'] as Map)['t1'] as Map;
        ((tpl['sessions'] as List).first as Map)['focus'] = 'full_body';
        expect(() => KnowledgeBase.fromJson(json), rejects('full_body'));
      });

      test('un defaultSchedule verso una seduta inesistente è rifiutato', () {
        final json = minimalBundle();
        final tpl = (json['templates'] as Map)['t1'] as Map;
        (tpl['defaultSchedule'] as Map)['mon'] = 'ghost';
        expect(() => KnowledgeBase.fromJson(json), rejects('ghost'));
      });

      test('un superset senza label è rifiutato', () {
        final json = minimalBundle();
        final tpl = (json['templates'] as Map)['t1'] as Map;
        final block =
            ((tpl['sessions'] as List).first as Map)['blocks'] as List;
        (block.first as Map)['type'] = 'superset';
        expect(() => KnowledgeBase.fromJson(json), rejects('label'));
      });

      test('il gruppo mesocycle è obbligatorio', () {
        final json = minimalBundle();
        (json['parameters'] as Map).remove('mesocycle');
        expect(() => KnowledgeBase.fromJson(json), rejects('mesocycle'));
      });

      test('weeks deve essere una lista', () {
        final json = minimalBundle();
        final meso = (json['parameters'] as Map)['mesocycle'] as Map;
        meso['values'] = {'weeks': 'cinque'};
        expect(() => KnowledgeBase.fromJson(json), rejects('weeks'));
      });

      test('una settimana mal tipizzata è rifiutata', () {
        for (final bad in <Map<String, Object?>>[
          {'number': '1', 'type': 'load', 'rirTarget': 3},
          {'number': 1, 'type': 'altro', 'rirTarget': 3},
          {'number': 1, 'type': 'load', 'rirTarget': 2.5},
        ]) {
          final json = minimalBundle();
          final meso = (json['parameters'] as Map)['mesocycle'] as Map;
          meso['values'] = {
            'weeks': [bad],
          };
          expect(() => KnowledgeBase.fromJson(json), rejects('weeks[0]'));
        }
      });

      test('trialLoad senza la motivazione TRIAL-LOAD è rifiutato', () {
        final json = minimalBundle();
        (json['parameters'] as Map)['trialLoad'] = {
          'group': 'trialLoad',
          'target': 'parameters',
          'values': {'x': 1},
          'provisional': true,
        };
        expect(() => KnowledgeBase.fromJson(json), rejects('TRIAL-LOAD'));
      });
    });
  });
}
