import '../contract/profile.dart';
import '../generate/generate_plan.dart' show generatePlanForProfile;
import '../generate/rationales.dart' show buildRationales;
import '../generate/result.dart';
import '../kb/knowledge_base.dart';
import 'photo_emphasis_rules.dart';
import 'photo_types.dart';

/// Formato del JSON di [suggestEmphasisFromJson].
const String suggestionSchemaVersion = '1.0';

/// Le condizioni della regola per una regione: vero, falso o nullo se non
/// sono state valutate (una condizione falsa ferma le successive).
class EmphasisEvidence {
  const EmphasisEvidence({
    required this.region,
    required this.observation,
    required this.confidence,
    required this.minConfidence,
    this.lessProminent,
    this.confidenceEnough,
    this.emphasizable,
    this.dataAvailable,
    this.dataAgrees,
    this.hasRoom,
    this.volumeWithinLimit,
    this.plannedWeeklySets,
    this.doneWeeklySets,
    this.doneOverPlanned,
    this.recoveryRespected,
    this.extraWeeklySets,
  });

  final PhotoRegion region;
  final PhotoObservation observation;
  final PhotoConfidence confidence;

  /// Confidenza minima della KB.
  final PhotoConfidence minConfidence;

  /// (a) l'osservazione è `less_prominent`.
  final bool? lessProminent;

  /// (b) la confidenza è almeno quella minima.
  final bool? confidenceEnough;

  /// (c) la regione ha un valore di `emphasis`.
  final bool? emphasizable;

  /// (d) ci sono dati di allenamento sufficienti per il distretto.
  final bool? dataAvailable;

  /// (d) i dati non contraddicono la foto: volume fatto né sopra il previsto
  /// né troppo sotto, recupero rispettato.
  final bool? dataAgrees;

  /// (e) la scelta cambia il piano (c'è tempo per l'enfasi).
  final bool? hasRoom;

  /// (e) le serie in più restano entro il tetto della KB.
  final bool? volumeWithinLimit;

  final double? plannedWeeklySets;
  final double? doneWeeklySets;
  final double? doneOverPlanned;
  final bool? recoveryRespected;

  /// Serie settimanali in più del piano di partenza con questa scelta.
  final double? extraWeeklySets;

  Map<String, Object?> toJson() => {
    'region': region.json,
    'observation': observation.json,
    'confidence': confidence.json,
    'minConfidence': minConfidence.json,
    'conditions': {
      if (lessProminent != null) 'lessProminent': lessProminent,
      if (confidenceEnough != null) 'confidenceEnough': confidenceEnough,
      if (emphasizable != null) 'emphasizable': emphasizable,
      if (dataAvailable != null) 'dataAvailable': dataAvailable,
      if (dataAgrees != null) 'dataAgrees': dataAgrees,
      if (hasRoom != null) 'hasRoom': hasRoom,
      if (volumeWithinLimit != null) 'volumeWithinLimit': volumeWithinLimit,
    },
    'data': {
      if (plannedWeeklySets != null) 'plannedWeeklySets': plannedWeeklySets,
      if (doneWeeklySets != null) 'doneWeeklySets': doneWeeklySets,
      if (doneOverPlanned != null) 'doneOverPlanned': doneOverPlanned,
      if (recoveryRespected != null) 'recoveryRespected': recoveryRespected,
      if (extraWeeklySets != null) 'extraWeeklySets': extraWeeklySets,
    },
  };
}

/// Un distretto suggerito.
class EmphasisPick {
  const EmphasisPick({
    required this.emphasis,
    required this.ruleId,
    required this.evidence,
  });

  /// Valore di `emphasis` del profilo.
  final String emphasis;

  /// Motivazione (testo it/en nella KB), sempre `PHOTO-EMPHASIS-SUGGEST`.
  final String ruleId;
  final EmphasisEvidence evidence;
}

/// Un candidato scartato, con il perché.
class SkippedCandidate {
  const SkippedCandidate({
    required this.region,
    required this.ruleId,
    required this.evidence,
  });

  final PhotoRegion region;
  final String ruleId;
  final EmphasisEvidence evidence;
}

/// Esito di [suggestEmphasis].
sealed class EmphasisSuggestionResult {
  const EmphasisSuggestionResult();
}

/// Al più `maxEmphasis` distretti per `emphasis` del ciclo successivo,
/// ordinati per priorità (valore completo da scrivere nel profilo).
final class EmphasisSuggestion extends EmphasisSuggestionResult {
  const EmphasisSuggestion({required this.picks, required this.skipped});

  final List<EmphasisPick> picks;

  /// Candidati scartati, nell'ordine di priorità.
  final List<SkippedCandidate> skipped;

  List<String> get emphasis => [for (final p in picks) p.emphasis];
}

/// Nessuna modifica: [ruleId] dice perché.
final class NoChange extends EmphasisSuggestionResult {
  const NoChange({required this.ruleId, required this.skipped});

  final String ruleId;
  final List<SkippedCandidate> skipped;
}

class _Candidate {
  _Candidate(this.observation, this.emphasis);

  final RegionObservation observation;
  final String emphasis;
}

EmphasisEvidence _evidence(
  RegionObservation o,
  PhotoEmphasisRules rules, {
  bool? lessProminent,
  bool? confidenceEnough,
  bool? emphasizable,
  bool? dataAvailable,
  bool? dataAgrees,
  bool? hasRoom,
  bool? volumeWithinLimit,
  RegionTrainingStats? stats,
  double? extra,
}) {
  final ratio = stats != null && stats.plannedWeeklySets > 0
      ? stats.doneWeeklySets / stats.plannedWeeklySets
      : null;
  return EmphasisEvidence(
    region: o.region,
    observation: o.observation,
    confidence: o.confidence,
    minConfidence: rules.minConfidence,
    lessProminent: lessProminent,
    confidenceEnough: confidenceEnough,
    emphasizable: emphasizable,
    dataAvailable: dataAvailable,
    dataAgrees: dataAgrees,
    hasRoom: hasRoom,
    volumeWithinLimit: volumeWithinLimit,
    plannedWeeklySets: stats?.plannedWeeklySets,
    doneWeeklySets: stats?.doneWeeklySets,
    doneOverPlanned: ratio,
    recoveryRespected: stats?.recoveryRespected,
    extraWeeklySets: extra,
  );
}

/// Serie del piano generato (`sessions[].blocks[].exercises[].sets`).
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

Map<String, Object?>? _plan(Profile profile, KnowledgeBase kb) {
  final r = generatePlanForProfile(profile, kb);
  return r is Generated ? r.plan : null;
}

/// Suggerisce al più `maxEmphasis` distretti per `emphasis` del ciclo
/// successivo dalle osservazioni delle foto, o nessuna modifica.
///
/// Una regione entra solo se (a) è `less_prominent`, (b) con confidenza almeno
/// quella della KB, (c) ha un valore di `emphasis`, (d) i dati di allenamento
/// non la contraddicono (volume fatto non sopra il previsto né troppo sotto,
/// recupero rispettato, dati sufficienti) e (e) la scelta cambia il piano di
/// partenza di non più del tetto di serie in più della KB. Con più candidati
/// si ordina per confidenza e poi per l'ordine della KB: nessuna casualità.
///
/// Pura e deterministica. Lancia [KbFormatException] se la KB non ha il gruppo
/// `photoEmphasis` o non è valido; mai per le osservazioni, il profilo o i
/// dati. La foto non decide il volume: il tetto di serie in più impedisce a
/// una foto di aumentarlo oltre quello della KB.
EmphasisSuggestionResult suggestEmphasis(
  PhotoObservations observations,
  Profile profile,
  TrainingStats stats,
  KnowledgeBase kb,
) {
  final rules = PhotoEmphasisRules.fromKb(kb);

  // (a), (b), (c).
  final candidates = <_Candidate>[];
  for (final o in observations.regions) {
    final less = o.observation == PhotoObservation.lessProminent;
    final sure = o.confidence.rank >= rules.minConfidence.rank;
    final emphasis = rules.emphasisOf[o.region];
    if (less && sure && emphasis != null) {
      candidates.add(_Candidate(o, emphasis));
    }
  }
  if (candidates.isEmpty) {
    return const NoChange(ruleId: ruleNoEvidence, skipped: []);
  }
  candidates.sort((a, b) {
    final byConfidence = b.observation.confidence.rank.compareTo(
      a.observation.confidence.rank,
    );
    if (byConfidence != 0) return byConfidence;
    return rules.regionOrder
        .indexOf(a.observation.region)
        .compareTo(rules.regionOrder.indexOf(b.observation.region));
  });

  final skipped = <SkippedCandidate>[];
  void skip(_Candidate c, String ruleId, EmphasisEvidence evidence) =>
      skipped.add(
        SkippedCandidate(
          region: c.observation.region,
          ruleId: ruleId,
          evidence: evidence,
        ),
      );

  // (d).
  final dataOk = <_Candidate>[];
  for (final c in candidates) {
    final o = c.observation;
    final s = stats.of(o.region);
    if (s == null || s.plannedWeeklySets < rules.minPlannedWeeklySets) {
      skip(
        c,
        ruleNoData,
        _evidence(
          o,
          rules,
          lessProminent: true,
          confidenceEnough: true,
          emphasizable: true,
          dataAvailable: false,
          stats: s,
        ),
      );
      continue;
    }
    final ratio = s.doneWeeklySets / s.plannedWeeklySets;
    final agrees =
        ratio <= rules.maxDoneOverPlanned &&
        ratio >= rules.minDoneOverPlanned &&
        s.recoveryRespected != false;
    if (!agrees) {
      skip(
        c,
        ruleDataDisagrees,
        _evidence(
          o,
          rules,
          lessProminent: true,
          confidenceEnough: true,
          emphasizable: true,
          dataAvailable: true,
          dataAgrees: false,
          stats: s,
        ),
      );
      continue;
    }
    dataOk.add(c);
  }

  // (e): si prova ogni scelta sul piano che il motore genererebbe.
  final picks = <EmphasisPick>[];
  if (dataOk.isNotEmpty) {
    final base = _plan(profile, kb);
    final baseSets = base == null ? null : _planSets(base);
    final accepted = <String>[];
    var previous = base;
    for (final c in dataOk) {
      final o = c.observation;
      final s = stats.of(o.region)!;
      EmphasisEvidence ev({bool? room, bool? volume, double? extra}) =>
          _evidence(
            o,
            rules,
            lessProminent: true,
            confidenceEnough: true,
            emphasizable: true,
            dataAvailable: true,
            dataAgrees: true,
            hasRoom: room,
            volumeWithinLimit: volume,
            stats: s,
            extra: extra,
          );
      if (picks.length >= rules.maxEmphasis) break;
      if (accepted.contains(c.emphasis)) continue;
      final trial = _plan(profile.withEmphasis([...accepted, c.emphasis]), kb);
      if (base == null ||
          baseSets == null ||
          trial == null ||
          previous == null) {
        skip(c, ruleNoRoom, ev(room: false));
        continue;
      }
      if (_sameExercises(trial, previous)) {
        skip(c, ruleNoRoom, ev(room: false));
        continue;
      }
      final extra = (_planSets(trial) - baseSets).toDouble();
      if (extra > rules.maxExtraWeeklySets) {
        skip(c, ruleMoreVolume, ev(room: true, volume: false, extra: extra));
        continue;
      }
      accepted.add(c.emphasis);
      previous = trial;
      picks.add(
        EmphasisPick(
          emphasis: c.emphasis,
          ruleId: ruleSuggest,
          evidence: ev(room: true, volume: true, extra: extra),
        ),
      );
    }
  }

  if (picks.isNotEmpty) {
    return EmphasisSuggestion(picks: picks, skipped: skipped);
  }
  return NoChange(ruleId: skipped.first.ruleId, skipped: skipped);
}

/// Vero se i due piani hanno le stesse sedute con gli stessi esercizi e le
/// stesse serie, nello stesso ordine. Le etichette `rules` non contano: un
/// esercizio che l'enfasi mette al posto di una estensione uguale (stesso
/// esercizio, stesse serie) non cambia il lavoro del piano.
bool _sameExercises(Map<String, Object?> a, Map<String, Object?> b) =>
    _sameJson(_exerciseSignature(a), _exerciseSignature(b));

List<Object?> _exerciseSignature(Map<String, Object?> plan) => [
  for (final s in plan['sessions']! as List)
    [
      (s as Map)['id'],
      for (final b in s['blocks'] as List)
        for (final e in (b as Map)['exercises'] as List)
          [(e as Map)['exerciseId'], e['sets']],
    ],
];

bool _sameJson(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final k in a.keys) {
      if (!b.containsKey(k) || !_sameJson(a[k], b[k])) return false;
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_sameJson(a[i], b[i])) return false;
    }
    return true;
  }
  return a == b;
}

/// Esito di [suggestEmphasisFromJson] per un ingresso non valido.
Map<String, Object?> _invalid(List<String> errors) => {
  'schemaVersion': suggestionSchemaVersion,
  'result': 'invalid',
  'errors': errors,
};

/// Versione JSON di [suggestEmphasis] per la riga di comando e il servizio.
///
/// Ingresso: `{profile, observations: {regions: [...]}, trainingStats:
/// {regions: [...]}}`, con `observations` nella forma del risultato
/// dell'analisi (i campi oltre `region`, `observation` e `confidence` si
/// ignorano). Uscita: `result` (`suggestion`, `no_change` o `invalid`),
/// `emphasis`, `picks`, `ruleId` (per `no_change`), `skipped`, `rationales`
/// (le motivazioni citate, con i testi it/en e le fonti) e `rulesVersion`.
/// Non lancia: un ingresso non valido o una KB senza il gruppo `photoEmphasis`
/// danno `result: invalid` con gli errori.
Map<String, Object?> suggestEmphasisFromJson(
  Map<String, Object?> input,
  KnowledgeBase kb,
) {
  final errors = <String>[];
  final profileRead = input['profile'] is Map<String, Object?>
      ? readProfile(input['profile']! as Map<String, Object?>)
      : null;
  if (profileRead == null) {
    errors.add('profile: atteso un oggetto');
  } else if (profileRead is ProfileErrors) {
    errors.addAll([for (final e in profileRead.errors) 'profile.$e']);
  }
  final observations = PhotoObservations.fromJson(
    input['observations'],
    errors,
  );
  final stats = TrainingStats.fromJson(input['trainingStats'], errors);
  if (errors.isNotEmpty ||
      profileRead is! ProfileOk ||
      observations == null ||
      stats == null) {
    return _invalid(errors);
  }
  final EmphasisSuggestionResult result;
  try {
    result = suggestEmphasis(observations, profileRead.profile, stats, kb);
  } on Exception catch (e) {
    return _invalid(['kb: $e']);
  }
  final ruleIds = <String>{
    switch (result) {
      EmphasisSuggestion() => ruleSuggest,
      NoChange(:final ruleId) => ruleId,
    },
  };
  final skipped = switch (result) {
    EmphasisSuggestion(:final skipped) => skipped,
    NoChange(:final skipped) => skipped,
  };
  ruleIds.addAll([for (final s in skipped) s.ruleId]);
  return {
    'schemaVersion': suggestionSchemaVersion,
    'rulesVersion': kb.rulesVersion,
    ...switch (result) {
      EmphasisSuggestion(:final picks, :final emphasis) => {
        'result': 'suggestion',
        'emphasis': emphasis,
        'picks': [
          for (final p in picks)
            {
              'emphasis': p.emphasis,
              'ruleId': p.ruleId,
              'evidence': p.evidence.toJson(),
            },
        ],
      },
      NoChange(:final ruleId) => {
        'result': 'no_change',
        'ruleId': ruleId,
        'emphasis': <String>[],
      },
    },
    'skipped': [
      for (final s in skipped)
        {
          'region': s.region.json,
          'ruleId': s.ruleId,
          'evidence': s.evidence.toJson(),
        },
    ],
    'rationales': [
      for (final r in buildRationales(kb, forPlan: false))
        if (ruleIds.contains(r['ruleId'])) r,
    ],
  };
}
