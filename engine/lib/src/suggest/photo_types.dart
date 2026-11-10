/// Tipi di ingresso di `suggestEmphasis`: osservazioni delle foto e statistiche
/// di allenamento. Le stringhe sono quelle del risultato dell'analisi
/// dell'app (`analysis_result.dart`): formato, non numeri di dominio.
library;

/// Regione che l'analisi delle foto commenta.
enum PhotoRegion {
  shoulders('shoulders'),
  chest('chest'),
  back('back'),
  arms('arms'),
  core('core'),
  quadriceps('quadriceps'),
  hamstrings('hamstrings'),
  glutes('glutes'),
  calves('calves');

  const PhotoRegion(this.json);

  final String json;

  static PhotoRegion? parse(Object? v) {
    for (final r in values) {
      if (r.json == v) return r;
    }
    return null;
  }
}

/// Cosa dice l'analisi di una regione.
enum PhotoObservation {
  lessProminent('less_prominent'),
  balanced('balanced'),
  moreProminent('more_prominent'),
  insufficientEvidence('insufficient_evidence');

  const PhotoObservation(this.json);

  final String json;

  static PhotoObservation? parse(Object? v) {
    for (final o in values) {
      if (o.json == v) return o;
    }
    return null;
  }
}

/// Quanto è sicura l'analisi di un'osservazione.
enum PhotoConfidence {
  insufficient('insufficient', 0),
  low('low', 1),
  medium('medium', 2),
  high('high', 3);

  const PhotoConfidence(this.json, this.rank);

  final String json;

  /// Posizione dal più basso al più alto.
  final int rank;

  static PhotoConfidence? parse(Object? v) {
    for (final c in values) {
      if (c.json == v) return c;
    }
    return null;
  }
}

/// Osservazione di una regione, con la sua confidenza.
class RegionObservation {
  const RegionObservation({
    required this.region,
    required this.observation,
    required this.confidence,
  });

  final PhotoRegion region;
  final PhotoObservation observation;
  final PhotoConfidence confidence;
}

/// Osservazioni per distretto di un'analisi delle foto. Il JSON è quello del
/// risultato dell'analisi (`regions[]`); gli altri campi si ignorano.
class PhotoObservations {
  const PhotoObservations(this.regions);

  final List<RegionObservation> regions;

  /// Legge `{regions: [{region, observation, confidence, ...}]}`; gli errori
  /// vanno in [errors] (percorso e motivo).
  static PhotoObservations? fromJson(Object? json, List<String> errors) {
    if (json is! Map || json['regions'] is! List) {
      errors.add('observations.regions: attesa una lista');
      return null;
    }
    final list = json['regions']! as List;
    final out = <RegionObservation>[];
    final seen = <PhotoRegion>{};
    var ok = true;
    for (var i = 0; i < list.length; i++) {
      final path = 'observations.regions[$i]';
      final m = list[i];
      if (m is! Map) {
        errors.add('$path: attesa una mappa');
        ok = false;
        continue;
      }
      final region = PhotoRegion.parse(m['region']);
      final observation = PhotoObservation.parse(m['observation']);
      final confidence = PhotoConfidence.parse(m['confidence']);
      if (region == null) errors.add('$path.region: valore non valido');
      if (observation == null) {
        errors.add('$path.observation: valore non valido');
      }
      if (confidence == null) errors.add('$path.confidence: valore non valido');
      if (region == null || observation == null || confidence == null) {
        ok = false;
        continue;
      }
      if (!seen.add(region)) {
        errors.add('$path.region: regione ripetuta');
        ok = false;
        continue;
      }
      out.add(
        RegionObservation(
          region: region,
          observation: observation,
          confidence: confidence,
        ),
      );
    }
    return ok ? PhotoObservations(out) : null;
  }
}

/// Statistiche di allenamento di un distretto nel ciclo che finisce.
///
/// L'app le calcola da dati che ha già: le serie di lavoro registrate per
/// muscolo (medie per settimana del ciclo), le serie previste dal piano per
/// lo stesso muscolo e le ore di recupero tra le sedute che lo allenano.
class RegionTrainingStats {
  const RegionTrainingStats({
    required this.region,
    required this.plannedWeeklySets,
    required this.doneWeeklySets,
    this.recoveryRespected,
  });

  final PhotoRegion region;

  /// Serie di lavoro a settimana previste dal piano, in media sul ciclo.
  final double plannedWeeklySets;

  /// Serie di lavoro a settimana fatte, in media sul ciclo.
  final double doneWeeklySets;

  /// Falso se qualche seduta del distretto è stata fatta con meno ore di
  /// recupero del minimo del piano; nullo se non si sa.
  final bool? recoveryRespected;
}

/// Statistiche di allenamento per distretto; una regione senza voce non ha
/// dati.
class TrainingStats {
  const TrainingStats(this.regions);

  final List<RegionTrainingStats> regions;

  RegionTrainingStats? of(PhotoRegion region) {
    for (final s in regions) {
      if (s.region == region) return s;
    }
    return null;
  }

  /// Legge `{regions: [{region, plannedWeeklySets, doneWeeklySets,
  /// recoveryRespected?}]}`.
  static TrainingStats? fromJson(Object? json, List<String> errors) {
    if (json is! Map || json['regions'] is! List) {
      errors.add('trainingStats.regions: attesa una lista');
      return null;
    }
    final list = json['regions']! as List;
    final out = <RegionTrainingStats>[];
    final seen = <PhotoRegion>{};
    var ok = true;
    for (var i = 0; i < list.length; i++) {
      final path = 'trainingStats.regions[$i]';
      final m = list[i];
      if (m is! Map) {
        errors.add('$path: attesa una mappa');
        ok = false;
        continue;
      }
      final region = PhotoRegion.parse(m['region']);
      final planned = m['plannedWeeklySets'];
      final done = m['doneWeeklySets'];
      final recovery = m['recoveryRespected'];
      var itemOk = true;
      if (region == null) {
        errors.add('$path.region: valore non valido');
        itemOk = false;
      }
      for (final e in {
        'plannedWeeklySets': planned,
        'doneWeeklySets': done,
      }.entries) {
        final v = e.value;
        if (v is! num || !v.isFinite || v < 0) {
          errors.add('${'$path.${e.key}'}: atteso un numero non negativo');
          itemOk = false;
        }
      }
      if (recovery != null && recovery is! bool) {
        errors.add('$path.recoveryRespected: atteso un booleano o null');
        itemOk = false;
      }
      if (!itemOk) {
        ok = false;
        continue;
      }
      if (!seen.add(region!)) {
        errors.add('$path.region: regione ripetuta');
        ok = false;
        continue;
      }
      out.add(
        RegionTrainingStats(
          region: region,
          plannedWeeklySets: (planned! as num).toDouble(),
          doneWeeklySets: (done! as num).toDouble(),
          recoveryRespected: recovery as bool?,
        ),
      );
    }
    return ok ? TrainingStats(out) : null;
  }
}
