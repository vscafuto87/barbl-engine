import '../kb/knowledge_base.dart';

const String _mesocycleGroup = 'mesocycle';
const String _parametersTarget = 'parameters';

/// Blocco `parameters` del piano: un oggetto per gruppo con `target: parameters`.
Map<String, Object?> buildParameters(KnowledgeBase kb) {
  final groups = kb.parameterGroups.values
      .where((g) => g.target == _parametersTarget)
      .toList()
    ..sort((a, b) => a.group.compareTo(b.group));
  return {
    for (final g in groups)
      g.group: <String, Object?>{
        ...g.values,
        'provisional': g.provisional,
        if (g.ruleId != null) 'ruleId': g.ruleId,
      },
  };
}

/// Blocco `mesocycle` del piano, dal gruppo `mesocycle` della KB.
Map<String, Object?> buildMesocycle(KnowledgeBase kb) {
  final group = kb.parameterGroups[_mesocycleGroup];
  if (group == null) {
    throw StateError('KB without parameter group $_mesocycleGroup');
  }
  final weeks = group.values['weeks'];
  if (weeks is! List) {
    throw StateError('KB group $_mesocycleGroup has no weeks list');
  }
  return {
    'weeks': [
      for (final w in weeks)
        if (w is Map)
          <String, Object?>{
            'number': w['number'],
            'type': w['type'],
            'rirTarget': w['rirTarget'],
            if (w['note'] != null) 'note': w['note'],
          },
    ],
  };
}
