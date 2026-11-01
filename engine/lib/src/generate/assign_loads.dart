import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import 'prescribe.dart';

/// Origine del carico iniziale di un esercizio.
enum LoadSource {
  profile,
  estimate,
  trialSet;

  String get json => switch (this) {
    LoadSource.profile => 'profile',
    LoadSource.estimate => 'estimate',
    LoadSource.trialSet => 'trial_set',
  };
}

/// Carico iniziale: `kg` nullo quando lo si chiede alla prima serie.
class InitialLoad {
  InitialLoad(this.kg, this.source);

  final double? kg;
  final LoadSource source;
}

/// RIR più alto tra le settimane di tipo `load` del mesociclo, o null.
int? _maxLoadRir(KnowledgeBase kb) {
  final group = kb.parameterGroups['mesocycle'];
  if (group == null) return null;
  final weeks = group.values['weeks'];
  if (weeks is! List) return null;
  int? best;
  for (final w in weeks) {
    if (w is! Map) continue;
    if (w['type'] != 'load') continue;
    final rir = w['rirTarget'];
    if (rir is! num) continue;
    final r = rir.toInt();
    if (best == null || r > best) best = r;
  }
  return best;
}

/// Limite di ripetizioni più RIR per proporre la serie di prova, o null.
num? _trialLimit(KnowledgeBase kb) {
  final group = kb.parameterGroups['trialLoad'];
  if (group == null) return null;
  final limit = group.engineConstraints['maxRepsPlusRir'];
  return limit is num ? limit : null;
}

/// Passo 4: carico iniziale di ogni esercizio scelto, per `exerciseId`.
///
/// Un carico noto del profilo vale per qualunque slot; altrimenti la serie di
/// prova se lo slot la chiede e la KB la ammette; altrimenti il carico si
/// digita alla prima serie (stima nulla). Le voci di `knownLoads` per esercizi
/// non scelti nel piano si ignorano.
Map<String, InitialLoad> assignLoads(
  List<PrescribedSession> sessions,
  Profile profile,
  KnowledgeBase kb,
) {
  // TODO(fase-14): conversione dei carichi noti, non ancora una regola della KB
  final limit = _trialLimit(kb);
  final maxRir = _maxLoadRir(kb);
  final result = <String, InitialLoad>{};
  for (final session in sessions) {
    for (final block in session.blocks) {
      for (final pe in block.exercises) {
        final id = pe.exercise.id;
        final known = profile.knownLoads[id];
        if (known != null) {
          result[id] = InitialLoad(known, LoadSource.profile);
          continue;
        }
        final existing = result[id];
        if (existing != null) {
          // Un'occorrenza precedente può aver già deciso la prova: la
          // prima assegnazione vale, salvo che questa sia una prova e la
          // precedente una stima.
          if (existing.source != LoadSource.estimate) continue;
        }
        final trial =
            pe.askLoad &&
            pe.exercise.whenLoadUnknown == 'trial_set' &&
            limit != null &&
            maxRir != null &&
            pe.repsMin + maxRir <= limit;
        result[id] = trial
            ? InitialLoad(null, LoadSource.trialSet)
            : InitialLoad(null, LoadSource.estimate);
      }
    }
  }
  return result;
}
