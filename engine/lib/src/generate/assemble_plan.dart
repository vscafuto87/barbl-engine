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

Map<String, Object?> _exercise(
  PrescribedExercise pe,
  Map<String, InitialLoad> loads,
  List<String> everyExerciseRules,
  KnowledgeBase kb,
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
  };
}

Map<String, Object?> _block(
  PrescribedBlock block,
  Map<String, InitialLoad> loads,
  List<String> rules,
  KnowledgeBase kb,
) {
  final isSuperset = block.type == 'superset';
  return {
    'type': block.type,
    if (isSuperset && block.label != null) 'label': block.label,
    if (isSuperset) 'restSeconds': block.restSeconds,
    'exercises': [
      for (final pe in block.exercises) _exercise(pe, loads, rules, kb),
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
  final rationales = buildRationales(kb);
  final everyExerciseRules = [
    for (final r in kb.rationales)
      if (r.everyExercise) r.ruleId,
  ]..sort();

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
    'schedule': [
      for (final day in _weekDays)
        if (template.defaultSchedule.containsKey(day))
          {'day': day, 'sessionId': template.defaultSchedule[day]},
    ],
    'sessions': [
      for (final s in sessions)
        {
          'id': s.id,
          'name': s.nameIt,
          'focus': s.focus,
          'estimatedDurationMin': s.estimatedDurationMin,
          'blocks': [
            for (final b in s.blocks) _block(b, loads, everyExerciseRules, kb),
          ],
        },
    ],
    'rationales': rationales,
    'parameters': buildParameters(kb),
  };

  _checkRules(plan, rationales);
  return plan;
}

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
