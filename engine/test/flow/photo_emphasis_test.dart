/// `suggestEmphasis` con la KB vera: ogni condizione della regola (a-e) in
/// positivo e in negativo, il tetto di due distretti, l'ordine deterministico,
/// il JSON, e la garanzia che `generatePlan` non cambia.
library;

import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:test/test.dart';

late Map<String, Object?> bundleJson;
late KnowledgeBase kb;

Map<String, Object?> _golden(String name) =>
    jsonDecode(File('../kb/golden/$name').readAsStringSync())
        as Map<String, Object?>;

Profile _profile(String name, {int? minutes}) {
  final json = _golden(name);
  if (minutes != null) json['sessionDurationMin'] = minutes;
  final read = readProfile(json);
  expect(read, isA<ProfileOk>(), reason: name);
  return (read as ProfileOk).profile;
}

/// KB con un altro valore in `photoEmphasis`.
KnowledgeBase _kbWith(Map<String, Object?> changes) {
  final copy = jsonDecode(jsonEncode(bundleJson)) as Map<String, Object?>;
  final group =
      ((copy['parameters']! as Map)['photoEmphasis']! as Map)['values']! as Map;
  group.addAll(changes);
  return KnowledgeBase.fromJson(copy);
}

RegionObservation _obs(
  PhotoRegion region, {
  PhotoObservation observation = PhotoObservation.lessProminent,
  PhotoConfidence confidence = PhotoConfidence.high,
}) => RegionObservation(
  region: region,
  observation: observation,
  confidence: confidence,
);

/// Dati compatibili con la foto: ciclo fatto per intero, recupero rispettato.
RegionTrainingStats _stats(
  PhotoRegion region, {
  double planned = 10,
  double done = 9,
  bool? recovery = true,
}) => RegionTrainingStats(
  region: region,
  plannedWeeklySets: planned,
  doneWeeklySets: done,
  recoveryRespected: recovery,
);

TrainingStats _allStats() =>
    TrainingStats([for (final r in PhotoRegion.values) _stats(r)]);

EmphasisSuggestionResult _suggest(
  List<RegionObservation> obs, {
  String profile = 'profile-example.json',
  int? minutes,
  TrainingStats? stats,
  KnowledgeBase? withKb,
}) => suggestEmphasis(
  PhotoObservations(obs),
  _profile(profile, minutes: minutes),
  stats ?? _allStats(),
  withKb ?? kb,
);

String _noChange(EmphasisSuggestionResult r) {
  expect(r, isA<NoChange>(), reason: '$r');
  return (r as NoChange).ruleId;
}

int _planSets(Map<String, Object?> plan) {
  var total = 0;
  for (final s in plan['sessions']! as List) {
    for (final b in (s as Map)['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        total += ((e as Map)['sets']! as num).toInt();
      }
    }
  }
  return total;
}

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    bundleJson = built.json;
    kb = KnowledgeBase.fromJson(bundleJson);
  });

  group('caso positivo', () {
    test('un distretto less_prominent con dati compatibili è suggerito', () {
      final r = _suggest([_obs(PhotoRegion.quadriceps)]);
      expect(r, isA<EmphasisSuggestion>());
      final s = r as EmphasisSuggestion;
      expect(s.emphasis, ['quadriceps']);
      final pick = s.picks.single;
      expect(pick.ruleId, 'PHOTO-EMPHASIS-SUGGEST');
      final ev = pick.evidence;
      expect(ev.region, PhotoRegion.quadriceps);
      expect(ev.lessProminent, isTrue);
      expect(ev.confidenceEnough, isTrue);
      expect(ev.emphasizable, isTrue);
      expect(ev.dataAvailable, isTrue);
      expect(ev.dataAgrees, isTrue);
      expect(ev.hasRoom, isTrue);
      expect(ev.volumeWithinLimit, isTrue);
      expect(ev.doneOverPlanned, closeTo(0.9, 1e-9));
      expect(ev.extraWeeklySets, lessThanOrEqualTo(3));
    });

    test('nessuna osservazione: nessuna modifica', () {
      expect(_noChange(_suggest([])), 'PHOTO-EMPHASIS-NO-EVIDENCE');
    });
  });

  group('(a) osservazione', () {
    for (final o in [
      PhotoObservation.balanced,
      PhotoObservation.moreProminent,
      PhotoObservation.insufficientEvidence,
    ]) {
      test('${o.json} non basta', () {
        final r = _suggest([_obs(PhotoRegion.quadriceps, observation: o)]);
        expect(_noChange(r), 'PHOTO-EMPHASIS-NO-EVIDENCE');
      });
    }

    test(
      'confidenza insufficient con insufficient_evidence: nessuna modifica',
      () {
        final r = _suggest([
          _obs(
            PhotoRegion.quadriceps,
            observation: PhotoObservation.insufficientEvidence,
            confidence: PhotoConfidence.insufficient,
          ),
        ]);
        expect(_noChange(r), 'PHOTO-EMPHASIS-NO-EVIDENCE');
      },
    );
  });

  group('(b) confidenza', () {
    test('la confidenza minima della KB basta, quella sotto no', () {
      expect(
        _suggest([
          _obs(PhotoRegion.quadriceps, confidence: PhotoConfidence.medium),
        ]),
        isA<EmphasisSuggestion>(),
      );
      for (final c in [PhotoConfidence.low, PhotoConfidence.insufficient]) {
        expect(
          _noChange(_suggest([_obs(PhotoRegion.quadriceps, confidence: c)])),
          'PHOTO-EMPHASIS-NO-EVIDENCE',
          reason: c.json,
        );
      }
    });

    test('la soglia viene dalla KB, non dal codice', () {
      final strict = _kbWith({'minConfidence': 'high'});
      final r = _suggest([
        _obs(PhotoRegion.quadriceps, confidence: PhotoConfidence.medium),
      ], withKb: strict);
      expect(_noChange(r), 'PHOTO-EMPHASIS-NO-EVIDENCE');
      final loose = _kbWith({'minConfidence': 'low'});
      expect(
        _suggest([
          _obs(PhotoRegion.quadriceps, confidence: PhotoConfidence.low),
        ], withKb: loose),
        isA<EmphasisSuggestion>(),
      );
    });
  });

  group('(c) distretto enfatizzabile', () {
    for (final r in [PhotoRegion.core, PhotoRegion.calves]) {
      test('${r.json} non ha un valore di emphasis', () {
        expect(_noChange(_suggest([_obs(r)])), 'PHOTO-EMPHASIS-NO-EVIDENCE');
      });
    }

    test('glutes e hamstrings vanno in glutes_hamstrings, una volta sola', () {
      final big = _kbWith({'maxExtraWeeklySets': 100});
      final r = _suggest([
        _obs(PhotoRegion.hamstrings, confidence: PhotoConfidence.medium),
        _obs(PhotoRegion.glutes),
      ], withKb: big);
      expect((r as EmphasisSuggestion).emphasis, ['glutes_hamstrings']);
      expect(r.picks.single.evidence.region, PhotoRegion.glutes);
    });
  });

  group('(d) dati di allenamento', () {
    EmphasisSuggestionResult withStats(RegionTrainingStats? s) =>
        _suggest([_obs(PhotoRegion.quadriceps)], stats: TrainingStats([?s]));

    test('volume fatto uguale al previsto va bene, sopra no', () {
      expect(
        withStats(_stats(PhotoRegion.quadriceps, done: 10)),
        isA<EmphasisSuggestion>(),
      );
      final r = withStats(_stats(PhotoRegion.quadriceps, done: 10.5));
      expect(_noChange(r), 'PHOTO-EMPHASIS-DATA-DISAGREES');
      final ev = (r as NoChange).skipped.single.evidence;
      expect(ev.dataAgrees, isFalse);
      expect(ev.doneOverPlanned, closeTo(1.05, 1e-9));
    });

    test('ciclo fatto per troppo poco: i dati non confermano', () {
      expect(
        withStats(_stats(PhotoRegion.quadriceps, done: 5)),
        isA<EmphasisSuggestion>(),
      );
      expect(
        _noChange(withStats(_stats(PhotoRegion.quadriceps, done: 4))),
        'PHOTO-EMPHASIS-DATA-DISAGREES',
      );
    });

    test('recupero violato contraddice, recupero ignoto no', () {
      expect(
        _noChange(withStats(_stats(PhotoRegion.quadriceps, recovery: false))),
        'PHOTO-EMPHASIS-DATA-DISAGREES',
      );
      expect(
        withStats(_stats(PhotoRegion.quadriceps, recovery: null)),
        isA<EmphasisSuggestion>(),
      );
    });

    test('senza dati o con troppo poco previsto: nessun dato', () {
      expect(_noChange(withStats(null)), 'PHOTO-EMPHASIS-NO-DATA');
      expect(
        _noChange(
          withStats(_stats(PhotoRegion.quadriceps, planned: 0, done: 0)),
        ),
        'PHOTO-EMPHASIS-NO-DATA',
      );
      // Dati di un altro distretto non valgono.
      final r = _suggest([
        _obs(PhotoRegion.quadriceps),
      ], stats: TrainingStats([_stats(PhotoRegion.chest)]));
      expect(_noChange(r), 'PHOTO-EMPHASIS-NO-DATA');
    });

    test('le soglie vengono dalla KB', () {
      final tight = _kbWith({
        'maxDoneOverPlanned': 0.5,
        'minDoneOverPlanned': 0,
      });
      final r = _suggest(
        [_obs(PhotoRegion.quadriceps)],
        stats: TrainingStats([_stats(PhotoRegion.quadriceps)]),
        withKb: tight,
      );
      expect(_noChange(r), 'PHOTO-EMPHASIS-DATA-DISAGREES');
      final planned = _kbWith({'minPlannedWeeklySets': 20});
      expect(
        _noChange(
          _suggest(
            [_obs(PhotoRegion.quadriceps)],
            stats: TrainingStats([_stats(PhotoRegion.quadriceps)]),
            withKb: planned,
          ),
        ),
        'PHOTO-EMPHASIS-NO-DATA',
      );
    });

    test('un candidato scartato non ferma gli altri', () {
      final r = _suggest(
        [_obs(PhotoRegion.chest), _obs(PhotoRegion.quadriceps)],
        stats: TrainingStats([
          _stats(PhotoRegion.chest, done: 30),
          _stats(PhotoRegion.quadriceps),
        ]),
      );
      expect((r as EmphasisSuggestion).emphasis, ['quadriceps']);
      expect(r.skipped.single.region, PhotoRegion.chest);
      expect(r.skipped.single.ruleId, 'PHOTO-EMPHASIS-DATA-DISAGREES');
    });
  });

  group('(e) volume totale', () {
    test('il tetto di serie in più viene dalla KB', () {
      // Nel piano a 3 giorni da 90 minuti l'enfasi sul petto aggiunge più
      // serie di quelle che la KB ammette (le sedute hanno ancora posto dopo
      // le estensioni).
      final chest = _suggest(
        [_obs(PhotoRegion.chest)],
        profile: 'profile-3d.json',
        minutes: 90,
      );
      expect(_noChange(chest), 'PHOTO-EMPHASIS-MORE-VOLUME');
      final ev = (chest as NoChange).skipped.single.evidence;
      expect(ev.volumeWithinLimit, isFalse);
      expect(ev.extraWeeklySets, greaterThan(3));
      final roomy = _kbWith({'maxExtraWeeklySets': 100});
      expect(
        _suggest(
          [_obs(PhotoRegion.chest)],
          profile: 'profile-3d.json',
          minutes: 90,
          withKb: roomy,
        ),
        isA<EmphasisSuggestion>(),
      );
      final zero = _kbWith({'maxExtraWeeklySets': 0});
      expect(
        _noChange(
          _suggest([_obs(PhotoRegion.quadriceps)], minutes: 75, withKb: zero),
        ),
        'PHOTO-EMPHASIS-MORE-VOLUME',
      );
    });

    test(
      'se la durata non lascia spazio il piano non cambia: nessun posto',
      () {
        final r = _suggest([
          _obs(PhotoRegion.chest),
        ], profile: 'profile-5d-45min.json');
        expect(_noChange(r), 'PHOTO-EMPHASIS-NO-ROOM');
        expect((r as NoChange).skipped.single.evidence.hasRoom, isFalse);
      },
    );

    test('un distretto già in emphasis non cambia il piano: nessun posto', () {
      final p = _profile('profile-example.json').withEmphasis(['quadriceps']);
      final r = suggestEmphasis(
        PhotoObservations([_obs(PhotoRegion.quadriceps)]),
        p,
        _allStats(),
        kb,
      );
      expect(_noChange(r), 'PHOTO-EMPHASIS-NO-ROOM');
    });

    test('ogni suggerimento resta nel tetto, nei piani veri', () {
      final roomy = _kbWith({'maxExtraWeeklySets': 6});
      for (final name in [
        'profile-3d.json',
        'profile-example.json',
        'profile-4d-strength.json',
        'profile-5d-45min.json',
        'profile-5d-60min-emphasis.json',
      ]) {
        final profile = _profile(name);
        final r = suggestEmphasis(
          PhotoObservations([
            for (final region in PhotoRegion.values) _obs(region),
          ]),
          profile,
          _allStats(),
          roomy,
        );
        if (r is! EmphasisSuggestion) continue;
        final base = (generatePlanForTest(profile, roomy));
        final next = generatePlanForTest(
          profile.withEmphasis(r.emphasis),
          roomy,
        );
        expect(
          _planSets(next) - _planSets(base),
          lessThanOrEqualTo(6),
          reason: name,
        );
        for (final s in next['sessions']! as List) {
          expect(
            (s as Map)['estimatedDurationMin'] as num,
            lessThanOrEqualTo(profile.sessionDurationMin),
            reason: name,
          );
        }
      }
    });
  });

  group('tetto di due e ordine', () {
    final roomy = {'maxExtraWeeklySets': 100};

    List<String> emphasisOf(
      List<RegionObservation> obs, {
      String profile = 'profile-3d.json',
    }) {
      final r = _suggest(
        obs,
        profile: profile,
        minutes: 90,
        withKb: _kbWith(roomy),
      );
      expect(r, isA<EmphasisSuggestion>());
      return (r as EmphasisSuggestion).emphasis;
    }

    test('al più due distretti, anche con quattro candidati', () {
      final e = emphasisOf([
        _obs(PhotoRegion.chest),
        _obs(PhotoRegion.back),
        _obs(PhotoRegion.shoulders),
        _obs(PhotoRegion.arms),
      ]);
      expect(e, hasLength(2));
    });

    test('il tetto viene dalla KB', () {
      final one = _kbWith({...roomy, 'maxEmphasis': 1});
      final r = _suggest(
        [_obs(PhotoRegion.chest), _obs(PhotoRegion.back)],
        profile: 'profile-3d.json',
        minutes: 90,
        withKb: one,
      );
      expect((r as EmphasisSuggestion).emphasis, hasLength(1));
    });

    test('prima la confidenza, poi l\'ordine della KB', () {
      expect(
        emphasisOf([
          _obs(PhotoRegion.chest, confidence: PhotoConfidence.medium),
          _obs(PhotoRegion.back),
        ]),
        ['back', 'chest'],
      );
      expect(emphasisOf([_obs(PhotoRegion.back), _obs(PhotoRegion.chest)]), [
        'chest',
        'back',
      ]);
    });

    test('l\'ordine delle osservazioni in ingresso non conta', () {
      final all = [
        _obs(PhotoRegion.arms),
        _obs(PhotoRegion.shoulders, confidence: PhotoConfidence.medium),
        _obs(PhotoRegion.back),
        _obs(PhotoRegion.chest),
      ];
      final expected = emphasisOf(all);
      expect(emphasisOf(all.reversed.toList()), expected);
      expect(emphasisOf([all[2], all[0], all[3], all[1]]), expected);
    });

    test('stesso ingresso, stessa uscita', () {
      final input = {
        'profile': _golden('profile-3d.json'),
        'observations': {
          'regions': [
            {
              'region': 'chest',
              'observation': 'less_prominent',
              'confidence': 'high',
            },
          ],
        },
        'trainingStats': {
          'regions': [
            {'region': 'chest', 'plannedWeeklySets': 10, 'doneWeeklySets': 8},
          ],
        },
      };
      final a = jsonEncode(suggestEmphasisFromJson(input, kb));
      final b = jsonEncode(suggestEmphasisFromJson(input, kb));
      expect(a, b);
    });
  });

  group('JSON', () {
    Map<String, Object?> input({
      List<Map<String, Object?>>? regions,
      List<Map<String, Object?>>? stats,
    }) => {
      'profile': _golden('profile-example.json'),
      'observations': {
        'schemaVersion': '1.0',
        'regions':
            regions ??
            [
              {
                'region': 'quadriceps',
                'observation': 'less_prominent',
                'confidence': 'high',
                'evidence': ['front'],
                'limitations': <String>[],
              },
            ],
        'retake_angles': <String>[],
        'insufficient_visual_evidence': false,
      },
      'trainingStats': {
        'regions':
            stats ??
            [
              {
                'region': 'quadriceps',
                'plannedWeeklySets': 10,
                'doneWeeklySets': 9,
                'recoveryRespected': true,
              },
            ],
      },
    };

    test('suggerimento con motivazione e prove', () {
      final out = suggestEmphasisFromJson(input(), kb);
      expect(out['result'], 'suggestion');
      expect(out['emphasis'], ['quadriceps']);
      expect(out['rulesVersion'], kb.rulesVersion);
      final pick = (out['picks']! as List).single as Map;
      expect(pick['ruleId'], 'PHOTO-EMPHASIS-SUGGEST');
      final conditions = (pick['evidence'] as Map)['conditions'] as Map;
      expect(conditions.values, everyElement(isTrue));
      final rationale = (out['rationales']! as List).single as Map;
      expect(rationale['ruleId'], 'PHOTO-EMPHASIS-SUGGEST');
      expect((rationale['text'] as Map).keys, containsAll(['it', 'en']));
      // JSON serializzabile così com'è.
      expect(() => jsonEncode(out), returnsNormally);
    });

    test('nessuna modifica con la sua motivazione', () {
      final out = suggestEmphasisFromJson(input(regions: []), kb);
      expect(out['result'], 'no_change');
      expect(out['ruleId'], 'PHOTO-EMPHASIS-NO-EVIDENCE');
      expect(out['emphasis'], isEmpty);
      expect(
        ((out['rationales']! as List).single as Map)['ruleId'],
        'PHOTO-EMPHASIS-NO-EVIDENCE',
      );
    });

    test('ingresso non valido: result invalid con gli errori', () {
      final out = suggestEmphasisFromJson({
        'profile': {'schemaVersion': '9.9'},
        'observations': {
          'regions': [
            {
              'region': 'nose',
              'observation': 'less_prominent',
              'confidence': 'high',
            },
          ],
        },
        'trainingStats': {
          'regions': [
            {'region': 'chest', 'plannedWeeklySets': -1, 'doneWeeklySets': 'x'},
          ],
        },
      }, kb);
      expect(out['result'], 'invalid');
      final errors = (out['errors']! as List).cast<String>();
      expect(errors.any((e) => e.startsWith('profile.')), isTrue);
      expect(
        errors.any((e) => e.contains('observations.regions[0].region')),
        isTrue,
      );
      expect(errors.any((e) => e.contains('plannedWeeklySets')), isTrue);
      expect(suggestEmphasisFromJson({}, kb)['result'], 'invalid');
    });

    test('una regione ripetuta è un errore', () {
      final one = {
        'region': 'chest',
        'observation': 'less_prominent',
        'confidence': 'high',
      };
      final out = suggestEmphasisFromJson(input(regions: [one, one]), kb);
      expect(out['result'], 'invalid');
    });
  });

  group('regole dalla KB', () {
    test('la KB vera le dà valide, provvisorie e senza numeri nel codice', () {
      final rules = PhotoEmphasisRules.fromKb(kb);
      expect(rules.maxEmphasis, lessThanOrEqualTo(emphasisMaxItems));
      expect(kb.parameterGroups['photoEmphasis']!.provisional, isTrue);
      expect(kb.parameterGroups['photoEmphasis']!.target, 'engine');
      expect(kb.principles.containsKey('P-PHOTO-EMPHASIS'), isTrue);
    });

    test('senza il gruppo suggestEmphasis lancia un errore chiaro', () {
      final copy = jsonDecode(jsonEncode(bundleJson)) as Map<String, Object?>;
      (copy['parameters']! as Map).remove('photoEmphasis');
      final without = KnowledgeBase.fromJson(copy);
      expect(
        () => _suggest([_obs(PhotoRegion.chest)], withKb: without),
        throwsA(
          isA<KbFormatException>().having(
            (e) => e.message,
            'message',
            contains('photoEmphasis'),
          ),
        ),
      );
      // La versione JSON non lancia.
      final out = suggestEmphasisFromJson({
        'profile': _golden('profile-example.json'),
        'observations': {'regions': <Object?>[]},
        'trainingStats': {'regions': <Object?>[]},
      }, without);
      expect(out['result'], 'invalid');
    });

    for (final key in [
      'minConfidence',
      'maxEmphasis',
      'regions',
      'notEmphasizable',
      'minPlannedWeeklySets',
      'minDoneOverPlanned',
      'maxDoneOverPlanned',
      'maxExtraWeeklySets',
    ]) {
      test('manca $key: errore che lo nomina, nessun valore inventato', () {
        final copy = jsonDecode(jsonEncode(bundleJson)) as Map<String, Object?>;
        final values =
            ((copy['parameters']! as Map)['photoEmphasis']! as Map)['values']!
                as Map;
        values.remove(key);
        final broken = KnowledgeBase.fromJson(copy);
        expect(
          () => PhotoEmphasisRules.fromKb(broken),
          throwsA(
            isA<KbFormatException>().having(
              (e) => e.message,
              'message',
              contains(key),
            ),
          ),
        );
      });
    }

    test('valori non validi sono rifiutati', () {
      for (final changes in <Map<String, Object?>>[
        {'minConfidence': 'insufficient'},
        {'minConfidence': 'certain'},
        {'maxEmphasis': 0},
        {'maxEmphasis': 3},
        {'minDoneOverPlanned': 2.0},
        {'maxExtraWeeklySets': -1},
        {
          'regions': [
            {'region': 'chest', 'emphasis': 'legs'},
          ],
        },
        {
          'notEmphasizable': ['chest'],
        },
      ]) {
        expect(
          () => PhotoEmphasisRules.fromKb(_kbWith(changes)),
          throwsA(isA<KbFormatException>()),
          reason: '$changes',
        );
      }
    });

    test('manca una motivazione: errore che la nomina', () {
      final copy = jsonDecode(jsonEncode(bundleJson)) as Map<String, Object?>;
      (copy['rationales']! as Map).remove('PHOTO-EMPHASIS-NO-ROOM');
      expect(
        () => PhotoEmphasisRules.fromKb(KnowledgeBase.fromJson(copy)),
        throwsA(
          isA<KbFormatException>().having(
            (e) => e.message,
            'message',
            contains('PHOTO-EMPHASIS-NO-ROOM'),
          ),
        ),
      );
    });
  });

  group('generatePlan non cambia', () {
    test(
      'lo stesso piano con e senza il gruppo e le motivazioni della foto',
      () {
        final copy = jsonDecode(jsonEncode(bundleJson)) as Map<String, Object?>;
        (copy['parameters']! as Map).remove('photoEmphasis');
        final rationales = copy['rationales']! as Map;
        for (final id in rationales.keys.toList()) {
          if ((id as String).startsWith('PHOTO-EMPHASIS')) {
            rationales.remove(id);
          }
        }
        final without = KnowledgeBase.fromJson(copy);
        for (final name in [
          'profile-example.json',
          'profile-3d.json',
          'profile-4d-strength.json',
          'profile-5d-45min.json',
          'profile-5d-60min-emphasis.json',
        ]) {
          final a = generatePlan(_golden(name), without) as Generated;
          final b = generatePlan(_golden(name), kb) as Generated;
          expect(jsonEncode(b.plan), jsonEncode(a.plan), reason: name);
          final plan = jsonEncode(b.plan);
          expect(plan, isNot(contains('PHOTO-EMPHASIS')), reason: name);
          expect(plan, isNot(contains('photoEmphasis')), reason: name);
        }
      },
    );

    test('l\'enfasi aggiunge serie solo dentro la durata scelta', () {
      // L'enfasi del motore non redistribuisce soltanto: aggiunge un
      // esercizio in coda alle sedute, ma solo se la seduta resta nei minuti
      // scelti. Per questo suggestEmphasis misura le serie in più su un piano
      // vero e le limita con il tetto della KB.
      for (final name in [
        'profile-3d.json',
        'profile-example.json',
        'profile-5d-45min.json',
      ]) {
        final base = _profile(name);
        final plain = generatePlanForTest(base.withEmphasis([]), kb);
        for (final e in emphasisValues) {
          final plan = generatePlanForTest(base.withEmphasis([e]), kb);
          expect(
            _planSets(plan),
            greaterThanOrEqualTo(_planSets(plain)),
            reason: '$name $e',
          );
          for (final s in plan['sessions']! as List) {
            expect(
              (s as Map)['estimatedDurationMin'] as num,
              lessThanOrEqualTo(base.sessionDurationMin),
              reason: '$name $e',
            );
          }
        }
      }
    });
  });
}

Map<String, Object?> generatePlanForTest(Profile p, KnowledgeBase k) {
  final r = generatePlanForProfile(p, k);
  expect(r, isA<Generated>());
  return (r as Generated).plan;
}
