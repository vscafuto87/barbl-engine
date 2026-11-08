import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'plan_parameters.dart' show deepCopy;

// Costanti di formato: etichetta di evidenza del contratto per ogni livello di
// fonte della KB (1 = position stand ... 5 = pratica dei coach).
const int _highEvidenceMaxTier = 2;
const int _mediumEvidenceMaxTier = 4;
const String _evidenceHigh = 'high';
const String _evidenceMedium = 'medium';
const String _evidenceLow = 'low';

// Fonti non mostrate all'utente.
const String _internalUse = 'internal';
const String _designType = 'design';
const String _parametersPrefix = 'parameters/';
const String _emptyReference = '—';

String _evidenceOfTier(int tier) {
  if (tier <= _highEvidenceMaxTier) return _evidenceHigh;
  if (tier <= _mediumEvidenceMaxTier) return _evidenceMedium;
  return _evidenceLow;
}

/// Identificativi dei principi da cui una motivazione prende le fonti.
List<String> _principleIds(KbRationale r, KnowledgeBase kb) {
  final from = r.sourcesFrom;
  if (from == null) return r.principles;
  final group = from.startsWith(_parametersPrefix)
      ? from.substring(_parametersPrefix.length)
      : from;
  final g = kb.parameterGroups[group];
  return g == null ? const [] : g.principles;
}

/// Fonti pubbliche di una motivazione, senza doppioni, per `tier` e `id`.
List<Map<String, Object?>> _publicSources(KbRationale r, KnowledgeBase kb) {
  final byId = <String, KbSource>{};
  for (final pid in _principleIds(r, kb)) {
    final principle = kb.principles[pid];
    if (principle == null) continue;
    for (final sid in principle.sources) {
      final s = kb.sources[sid];
      if (s == null) continue;
      if (s.use == _internalUse || s.type == _designType) continue;
      byId[s.id] = s;
    }
  }
  final sorted = byId.values.toList()
    ..sort((a, b) {
      final byTier = a.tier.compareTo(b.tier);
      return byTier != 0 ? byTier : a.id.compareTo(b.id);
    });
  return [
    for (final s in sorted)
      {
        'title': s.title,
        'reference': s.reference.isEmpty ? _emptyReference : s.reference,
        if (s.url != null) 'url': s.url,
        'evidence': _evidenceOfTier(s.tier),
      },
  ];
}

/// Una voce per motivazione della KB, ordinate per `ruleId`.
List<Map<String, Object?>> buildRationales(KnowledgeBase kb) {
  final ordered = [...kb.rationales]
    ..sort((a, b) => a.ruleId.compareTo(b.ruleId));
  return [
    for (final r in ordered)
      {
        'ruleId': r.ruleId,
        'level': r.level,
        'key': r.key,
        'values': deepCopy(r.exampleValues),
        'text': {'it': r.textIt, 'en': r.textEn},
        'sources': _publicSources(r, kb),
      },
  ];
}
