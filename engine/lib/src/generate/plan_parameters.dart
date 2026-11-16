import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart' show KbParameterGroup, intensityTechniquesGroup;

const String _mesocycleGroup = 'mesocycle';
const String _parametersTarget = 'parameters';

/// Copia profonda di Map e List, così il piano non condivide istanze con la KB.
Object? deepCopy(Object? v) {
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) e.key.toString(): deepCopy(e.value),
    };
  }
  if (v is List) {
    return <Object?>[for (final e in v) deepCopy(e)];
  }
  return v;
}

/// Blocco `parameters` del piano: un oggetto per gruppo con `target: parameters`.
/// Il gruppo `intensityTechniques` entra solo con [withTechniques] (un piano
/// con almeno un `lastSet`) e solo con i suoi `values`, come vuole il
/// contratto 3.2: così un piano senza tecniche resta identico a prima.
Map<String, Object?> buildParameters(
  KnowledgeBase kb, {
  bool withTechniques = false,
}) {
  final groups =
      kb.parameterGroups.values
          .where(
            (g) =>
                g.target == _parametersTarget &&
                g.group != intensityTechniquesGroup,
          )
          .toList()
        ..sort((a, b) => a.group.compareTo(b.group));
  final out = <String, Object?>{
    for (final g in groups)
      g.group: <String, Object?>{
        ...(deepCopy(g.values)! as Map<String, Object?>),
        'provisional': g.provisional,
        if (g.ruleId != null) 'ruleId': g.ruleId,
      },
  };
  if (withTechniques) {
    final g = kb.parameterGroups[intensityTechniquesGroup];
    if (g == null) {
      throw StateError(
        'plan with lastSet but KB without parameter group '
        '$intensityTechniquesGroup',
      );
    }
    out[intensityTechniquesGroup] = deepCopy(g.values);
    final ordered = out.keys.toList()..sort();
    return {for (final k in ordered) k: out[k]};
  }
  return out;
}

/// Settimane del mesociclo per l'esperienza del profilo: quelle di
/// `weeksByExperience[experience]` del gruppo `mesocycle` se ci sono,
/// altrimenti `weeks`. Nulla se la KB non ne ha.
List<Object?>? mesocycleWeeksFor(KnowledgeBase kb, Profile profile) {
  final group = kb.parameterGroups[_mesocycleGroup];
  if (group == null) return null;
  final byExperience = experienceWeeks(group, profile);
  if (byExperience != null) return byExperience;
  final weeks = group.values['weeks'];
  return weeks is List ? weeks : null;
}

/// Le settimane di `weeksByExperience` per l'esperienza del profilo, o null.
List<Object?>? experienceWeeks(KbParameterGroup group, Profile profile) {
  final byExperience = group.values['weeksByExperience'];
  if (byExperience is! Map) return null;
  final weeks = byExperience[profile.experience];
  return weeks is List ? weeks : null;
}

/// RIR minimo dei multiarticolari pesanti (`rirFloor` del piano 3.2) per
/// l'esperienza del profilo: `minRirHeavyCompoundByExperience` del gruppo
/// `mesocycle`. Sta sotto l'esperienza, come `weeksByExperience`, perché vale
/// solo con le sequenze di RIR che scendono a 0 (il mesociclo avanzato); nullo
/// se la KB non ne dà uno per quell'esperienza.
int? heavyCompoundRirFloor(KnowledgeBase kb, Profile profile) {
  final group = kb.parameterGroups[_mesocycleGroup];
  final byExperience = group?.values['minRirHeavyCompoundByExperience'];
  if (byExperience is! Map) return null;
  final v = byExperience[profile.experience];
  return v is int ? v : null;
}

/// RIR minimo delle settimane di carico per il livello di esperienza del
/// profilo (`minRirTargetByExperience` del gruppo `mesocycle`); nullo se la KB
/// non ne dà uno.
int? _minRirFor(KbParameterGroup group, Profile profile) {
  final byExperience = group.values['minRirTargetByExperience'];
  if (byExperience is! Map) return null;
  final v = byExperience[profile.experience];
  return v is int ? v : null;
}

/// Blocco `mesocycle` del piano, dal gruppo `mesocycle` della KB: le settimane
/// dell'esperienza del profilo (`weeksByExperience`) se ci sono, altrimenti
/// `weeks`. Le settimane di carico non scendono sotto il RIR minimo del
/// livello di esperienza (`P-RIR-BEGINNER`); lo scarico non cambia.
Map<String, Object?> buildMesocycle(KnowledgeBase kb, Profile profile) {
  final group = kb.parameterGroups[_mesocycleGroup];
  if (group == null) {
    throw StateError('KB without parameter group $_mesocycleGroup');
  }
  final weeks = experienceWeeks(group, profile) ?? group.values['weeks'];
  if (weeks is! List) {
    throw StateError('KB group $_mesocycleGroup has no weeks list');
  }
  final minRir = _minRirFor(group, profile);
  Object? rirOf(Map<Object?, Object?> w) {
    final rir = w['rirTarget'];
    if (minRir != null && w['type'] == 'load' && rir is int && rir < minRir) {
      return minRir;
    }
    return rir;
  }

  return {
    'weeks': [
      for (final w in weeks)
        if (w is Map)
          <String, Object?>{
            'number': w['number'],
            'type': w['type'],
            'rirTarget': rirOf(w),
            if (w['note'] != null) 'note': w['note'],
          },
    ],
  };
}
