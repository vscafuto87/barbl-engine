import 'dart:convert';

import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import '../version.dart';
import 'assign_loads.dart';
import 'plan_parameters.dart';
import 'prescribe.dart';
import 'rationales.dart';

// Costanti di formato del contratto del piano.
const String _planSchemaVersion = '3.0';
const String _trialRuleId = 'TRIAL-LOAD';
const List<String> _weekDays = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];

/// Il calendario del piano. Senza `weekdays` nel profilo vale quello
/// predefinito del template. Con i giorni scelti le sedute del template, nel
/// loro ordine di settimana, vanno ai giorni scelti, anch'essi in ordine di
/// settimana: la prima seduta al primo giorno, e così via. I giorni non
/// cambiano quali sedute ci sono né la loro prescrizione.
List<Map<String, Object?>> _schedule(KbTemplate template, Profile profile) {
  final sessionIds = [
    for (final day in _weekDays)
      if (template.defaultSchedule.containsKey(day))
        template.defaultSchedule[day]!,
  ];
  final days =
      profile.weekdays.isNotEmpty &&
          profile.weekdays.length == sessionIds.length
      ? profile.weekdays
      : [
          for (final day in _weekDays)
            if (template.defaultSchedule.containsKey(day)) day,
        ];
  return [
    for (var i = 0; i < sessionIds.length; i++)
      {'day': days[i], 'sessionId': sessionIds[i]},
  ];
}

/// Le alternative di [ex] per «Sostituisci»: i suoi sostituti nell'ordine
/// della KB, solo se eseguibili con l'attrezzatura del profilo e non già
/// presenti nella stessa seduta. Il carico non si converte (nessun rapporto
/// tra esercizi ha ancora una fonte): `manual`, scelto dall'utente in seduta.
List<Map<String, Object?>> _alternatives(
  KbExercise ex,
  Set<String> inSession,
  Profile profile,
  KnowledgeBase kb,
) {
  final out = <Map<String, Object?>>[];
  for (final id in ex.substitutes) {
    final alt = kb.exercises[id];
    if (alt == null || id == ex.id || inSession.contains(id)) continue;
    if (!alt.requires.every(profile.equipment.contains)) continue;
    out.add({
      'exerciseId': alt.id,
      'name': {'it': alt.nameIt, 'en': alt.nameEn},
      'equipment': alt.equipment,
      'muscles': [alt.primaryMuscle, ...alt.secondaryMuscles],
      if (alt.stepKg != null) 'stepKg': alt.stepKg,
      'initialLoad': {'kg': null, 'source': LoadSource.manual.json},
    });
  }
  return out;
}

Map<String, Object?> _exercise(
  PrescribedExercise pe,
  Map<String, InitialLoad> loads,
  List<String> everyExerciseRules,
  KnowledgeBase kb,
  Set<String> inSession,
  Profile profile,
) {
  final ex = pe.exercise;
  if (!kb.exercises.containsKey(ex.id)) {
    throw StateError('planned exercise ${ex.id} is not in the KB');
  }
  final load = loads[ex.id];
  if (load == null) {
    throw StateError('no initial load assigned to ${ex.id}');
  }
  final rules = [...everyExerciseRules];
  if (load.source == LoadSource.trialSet && !rules.contains(_trialRuleId)) {
    rules.add(_trialRuleId);
  }
  if (pe.fromEmphasis && !rules.contains(emphasisRuleId)) {
    rules.add(emphasisRuleId);
  }
  return {
    'exerciseId': ex.id,
    'name': {'it': ex.nameIt, 'en': ex.nameEn},
    'equipment': ex.equipment,
    'muscles': [ex.primaryMuscle, ...ex.secondaryMuscles],
    'sets': pe.sets,
    'reps': {'min': pe.repsMin, 'max': pe.repsMax},
    'rirFollowsMesocycle': pe.rirFollowsMesocycle,
    'restSeconds': pe.restSeconds,
    'warmup': pe.warmup,
    'initialLoad': {'kg': load.kg, 'source': load.source.json},
    if (ex.stepKg != null) 'stepKg': ex.stepKg,
    'rules': rules,
    if (pe.askLoad) 'askLoad': true,
    ..._withAlternatives(_alternatives(ex, inSession, profile, kb)),
  };
}

Map<String, Object?> _withAlternatives(List<Map<String, Object?>> list) =>
    list.isEmpty ? const {} : {'alternatives': list};

Map<String, Object?> _block(
  PrescribedBlock block,
  Map<String, InitialLoad> loads,
  List<String> rules,
  KnowledgeBase kb,
  Set<String> inSession,
  Profile profile,
) {
  final isSuperset = block.type == 'superset';
  return {
    'type': block.type,
    if (isSuperset && block.label != null) 'label': block.label,
    if (isSuperset) 'restSeconds': block.restSeconds,
    'exercises': [
      for (final pe in block.exercises)
        _exercise(pe, loads, rules, kb, inSession, profile),
    ],
  };
}

/// Passi 5 e 6: compone il piano del contratto e ne controlla la coerenza.
/// I controlli lanciano [StateError]: segnalano un errore della KB o del
/// motore, non un problema del profilo.
Map<String, Object?> assemblePlan({
  required KbTemplate template,
  required Profile profile,
  required List<PrescribedSession> sessions,
  required Map<String, InitialLoad> loads,
  required KnowledgeBase kb,
}) {
  final everyExerciseRules = [
    for (final r in kb.rationales)
      if (r.everyExercise) r.ruleId,
  ]..sort();
  final sessionsJson = <Map<String, Object?>>[
    for (final s in sessions)
      {
        'id': s.id,
        'name': s.nameIt,
        'focus': s.focus,
        'estimatedDurationMin': s.estimatedDurationMin,
        'blocks': [
          for (final b in s.blocks)
            _block(b, loads, everyExerciseRules, kb, {
              for (final bb in s.blocks)
                for (final e in bb.exercises) e.exercise.id,
            }, profile),
        ],
      },
  ];
  // La motivazione dell'enfasi entra solo nei piani che la usano, così un
  // piano senza enfasi resta identico a quello di una KB senza enfasi.
  final cited = _citedRules(sessionsJson);
  final rationales = [
    for (final r in buildRationales(kb))
      if (r['ruleId'] != emphasisRuleId || cited.contains(emphasisRuleId)) r,
  ];

  final plan = <String, Object?>{
    'schemaVersion': _planSchemaVersion,
    'id': '${template.id}-${profile.gymType}',
    'generatedBy': {
      'engine': 'barbl-engine $engineVersion',
      'rulesVersion': kb.rulesVersion,
    },
    'goal': profile.goal,
    'split': template.split,
    'mesocycle': buildMesocycle(kb),
    'schedule': _schedule(template, profile),
    'sessions': sessionsJson,
    'rationales': rationales,
    'parameters': buildParameters(kb),
  };

  _checkRules(plan, rationales);
  return plan;
}

/// Regole citate dagli esercizi delle sedute.
Set<String> _citedRules(List<Map<String, Object?>> sessions) => {
  for (final s in sessions)
    for (final b in s['blocks']! as List<Object?>)
      for (final e
          in (b! as Map<String, Object?>)['exercises']! as List<Object?>)
        for (final r in (e! as Map<String, Object?>)['rules']! as List<Object?>)
          r! as String,
};

/// Ogni regola citata da un esercizio ha la sua motivazione nel piano.
void _checkRules(
  Map<String, Object?> plan,
  List<Map<String, Object?>> rationales,
) {
  final known = {for (final r in rationales) r['ruleId']! as String};
  final sessions = plan['sessions']! as List<Object?>;
  for (final s in sessions) {
    final blocks = (s! as Map<String, Object?>)['blocks']! as List<Object?>;
    for (final b in blocks) {
      final exercises =
          (b! as Map<String, Object?>)['exercises']! as List<Object?>;
      for (final e in exercises) {
        final map = e! as Map<String, Object?>;
        for (final rule in map['rules']! as List<Object?>) {
          if (!known.contains(rule)) {
            throw StateError(
              'rule $rule of exercise ${map['exerciseId']} has no rationale',
            );
          }
        }
      }
    }
  }
  // Il piano deve poter diventare JSON.
  jsonEncode(plan);
}
