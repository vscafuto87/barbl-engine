import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart' show KbParameterGroup;

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
Map<String, Object?> buildParameters(KnowledgeBase kb) {
  final groups =
      kb.parameterGroups.values
          .where((g) => g.target == _parametersTarget)
          .toList()
        ..sort((a, b) => a.group.compareTo(b.group));
  return {
    for (final g in groups)
      g.group: <String, Object?>{
        ...(deepCopy(g.values)! as Map<String, Object?>),
        'provisional': g.provisional,
        if (g.ruleId != null) 'ruleId': g.ruleId,
      },
  };
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

/// Blocco `mesocycle` del piano, dal gruppo `mesocycle` della KB. Le settimane
/// di carico non scendono sotto il RIR minimo del livello di esperienza
/// (`P-RIR-BEGINNER`); lo scarico non cambia.
Map<String, Object?> buildMesocycle(KnowledgeBase kb, Profile profile) {
  final group = kb.parameterGroups[_mesocycleGroup];
  if (group == null) {
    throw StateError('KB without parameter group $_mesocycleGroup');
  }
  final weeks = group.values['weeks'];
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
