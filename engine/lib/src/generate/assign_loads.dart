import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import 'prescribe.dart';

/// Origine del carico iniziale di un esercizio.
enum LoadSource {
  profile,
  estimate,
  manual,
  trialSet;

  String get json => switch (this) {
    LoadSource.profile => 'profile',
    LoadSource.estimate => 'estimate',
    LoadSource.manual => 'manual',
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

/// Parametri della conversione di un carico noto con le ripetizioni.
class _Conversion {
  _Conversion(this.divisor, this.assumedRir);
  final num divisor;
  final num assumedRir;
}

_Conversion? _conversion(KnowledgeBase kb) {
  final group = kb.parameterGroups['trialLoad'];
  final c = group?.engineConstraints['knownLoadConversion'];
  if (c is! Map) return null;
  final d = c['epleyDivisor'];
  final r = c['assumedRir'];
  if (d is! num || d <= 0 || r is! num || r < 0) return null;
  return _Conversion(d, r);
}

/// RIR target della prima settimana di tipo `load`, o null.
int? _firstLoadRir(KnowledgeBase kb) {
  final weeks = kb.parameterGroups['mesocycle']?.values['weeks'];
  if (weeks is! List) return null;
  for (final w in weeks) {
    if (w is Map && w['type'] == 'load' && w['rirTarget'] is num) {
      return (w['rirTarget'] as num).toInt();
    }
  }
  return null;
}

/// Carico di lavoro da un carico fatto per [reps] ripetizioni: massimale
/// stimato con Epley, poi carico alle ripetizioni e al RIR target della
/// prima settimana, arrotondato al passo inferiore. Nullo se manca un dato.
double? _convertedKg({
  required double kg,
  required int reps,
  required PrescribedExercise pe,
  required _Conversion? conversion,
  required int? targetRir,
}) {
  final step = pe.exercise.stepKg;
  if (conversion == null || targetRir == null || step == null || step <= 0) {
    return null;
  }
  final e1rm = kg * (1 + (reps + conversion.assumedRir) / conversion.divisor);
  final work = e1rm / (1 + (pe.repsMin + targetRir) / conversion.divisor);
  return (work / step).floorToDouble() * step;
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
  final conversion = _conversion(kb);
  final firstRir = _firstLoadRir(kb);
  final limit = _trialLimit(kb);
  final maxRir = _maxLoadRir(kb);
  final result = <String, InitialLoad>{};
  for (final session in sessions) {
    for (final block in session.blocks) {
      for (final pe in block.exercises) {
        final id = pe.exercise.id;
        final known = profile.knownLoads[id];
        if (known != null) {
          final reps = profile.knownReps[id];
          final converted = reps == null
              ? null
              : _convertedKg(
                  kg: known,
                  reps: reps,
                  pe: pe,
                  conversion: conversion,
                  targetRir: firstRir,
                );
          result[id] = converted == null || converted <= 0
              ? InitialLoad(known, LoadSource.profile)
              : InitialLoad(converted, LoadSource.estimate);
          continue;
        }
        final existing = result[id];
        if (existing != null) {
          // Un'occorrenza precedente può aver già deciso la prova: la
          // prima assegnazione vale, salvo che questa sia una prova e la
          // precedente un carico manuale.
          if (existing.source != LoadSource.manual) continue;
        }
        final trial =
            pe.askLoad &&
            pe.exercise.whenLoadUnknown == 'trial_set' &&
            limit != null &&
            maxRir != null &&
            pe.repsMin + maxRir <= limit;
        result[id] = trial
            ? InitialLoad(null, LoadSource.trialSet)
            : InitialLoad(null, LoadSource.manual);
      }
    }
  }
  return result;
}
