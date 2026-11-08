import 'kb_format_exception.dart';
import 'models.dart';
import 'reader.dart';

/// Knowledge base letta dal pacchetto JSON (stessa forma che scrive `bundle`).
class KnowledgeBase {
  KnowledgeBase._({
    required this.rulesVersion,
    required this.kbCommit,
    required this.primaryWeight,
    required this.secondaryWeight,
    required this.exercises,
    required this.templates,
    required this.prescriptions,
    required this.parameterGroups,
    required this.rationales,
    required this.principles,
    required this.sources,
    required this.patternRegions,
    required this.emphases,
  });

  /// Formato del pacchetto che questa versione del motore sa leggere.
  static const int supportedBundleFormat = 1;

  factory KnowledgeBase.fromJson(Map<String, Object?> json) {
    const root = r'$';
    final format = intAt(json, 'bundleFormat', root);
    if (format != supportedBundleFormat) {
      throw KbFormatException(
        '$root.bundleFormat: formato $format non supportato '
        '(atteso $supportedBundleFormat)',
      );
    }
    final weights = mapAt(json, 'setWeights', root);

    Map<String, T> collection<T>(
      String key,
      T Function(Map<String, Object?>, String) read,
    ) {
      final m = mapAt(json, key, root);
      return {
        for (final e in m.entries)
          e.key: read(asMap(e.value, '$key.${e.key}'), '$key.${e.key}'),
      };
    }

    List<T> sortedList<T>(
      String key,
      T Function(Map<String, Object?>, String) read,
    ) {
      final m = mapAt(json, key, root);
      final ids = m.keys.toList()..sort();
      return [for (final id in ids) read(asMap(m[id], '$key.$id'), '$key.$id')];
    }

    final rationaleMap = collection('rationales', KbRationale.fromJson);
    final ruleIds = rationaleMap.keys.toList()..sort();

    final patternList = listAt(json, 'patterns', root);
    final patternRegions = <String, String>{};
    for (var i = 0; i < patternList.length; i++) {
      final path = 'patterns[$i]';
      final p = asMap(patternList[i], path);
      patternRegions[stringAt(p, 'id', path)] = stringAt(p, 'region', path);
    }

    // `emphasis` è facoltativo: un pacchetto senza la chiave non ha enfasi.
    final emphasisRaw = json['emphasis'] == null
        ? const <String, Object?>{}
        : mapAt(json, 'emphasis', root);
    final emphasisIds = emphasisRaw.keys.toList()..sort();
    final emphases = <String, KbEmphasis>{
      for (final id in emphasisIds)
        id: KbEmphasis.fromJson(
          asMap(emphasisRaw[id], 'emphasis.$id'),
          'emphasis.$id',
        ),
    };

    final kb = KnowledgeBase._(
      rulesVersion: stringAt(json, 'rulesVersion', root),
      kbCommit: stringOrNull(json, 'kbCommit', root),
      primaryWeight: doubleAt(weights, 'primary', 'setWeights'),
      secondaryWeight: doubleAt(weights, 'secondary', 'setWeights'),
      exercises: collection('exercises', KbExercise.fromJson),
      templates: sortedList('templates', KbTemplate.fromJson),
      prescriptions: sortedList('prescriptions', KbPrescription.fromJson),
      parameterGroups: collection('parameters', KbParameterGroup.fromJson),
      rationales: [for (final id in ruleIds) rationaleMap[id]!],
      principles: collection('principles', KbPrinciple.fromJson),
      sources: collection('sources', KbSource.fromJson),
      patternRegions: patternRegions,
      emphases: emphases,
    );
    _checkInvariants(kb);
    return kb;
  }

  /// Invarianti su cui si regge la generazione: il confine di fiducia è qui,
  /// non nel costruttore del pacchetto.
  static void _checkInvariants(KnowledgeBase kb) {
    for (final t in kb.templates) {
      final sessionIds = {for (final s in t.sessions) s.id};
      for (final e in t.defaultSchedule.entries) {
        if (!sessionIds.contains(e.value)) {
          throw KbFormatException(
            'templates.${t.id}.defaultSchedule.${e.key}: la seduta '
            '${e.value} non esiste nel template',
          );
        }
      }
      for (final s in t.sessions) {
        if (!supportedFocuses.contains(s.focus)) {
          throw KbFormatException(
            'templates.${t.id}.${s.id}: focus ${s.focus} non gestito '
            '(ammessi ${(supportedFocuses.toList()..sort()).join(', ')})',
          );
        }
        for (final b in s.blocks) {
          if (s.focus == 'full_body') {
            // La colonna di recupero di una seduta full body viene dalla
            // regione del pattern di ogni esercizio che può essere scelto.
            for (final slot in b.slots) {
              for (final id in slot.candidates) {
                final ex = kb.exercises[id];
                if (ex == null) continue;
                final region = kb.patternRegions[ex.pattern];
                if (region != regionUpper && region != regionLower) {
                  throw KbFormatException(
                    'templates.${t.id}.${s.id}: il pattern ${ex.pattern} di '
                    '$id non ha una regione ($regionUpper o $regionLower) '
                    'in patterns',
                  );
                }
              }
            }
          }
          if (b.type == 'superset' && b.label == null) {
            throw KbFormatException(
              'templates.${t.id}.${s.id}: un blocco superset senza label',
            );
          }
        }
      }
    }
    _checkEmphases(kb);
    final meso = kb.parameterGroups['mesocycle'];
    if (meso == null) {
      throw KbFormatException('parameters.mesocycle: gruppo mancante');
    }
    final weeks = meso.values['weeks'];
    if (weeks is! List) {
      throw KbFormatException(
        'parameters.mesocycle.values.weeks: deve essere una lista',
      );
    }
    for (var i = 0; i < weeks.length; i++) {
      final w = weeks[i];
      final path = 'parameters.mesocycle.values.weeks[$i]';
      if (w is! Map) {
        throw KbFormatException('$path: deve essere una mappa');
      }
      if (w['number'] is! int) {
        throw KbFormatException('$path.number: deve essere un intero');
      }
      if (w['type'] != 'load' && w['type'] != 'deload') {
        throw KbFormatException('$path.type: deve essere load o deload');
      }
      final rir = w['rirTarget'];
      if (rir != null && rir is! int) {
        throw KbFormatException('$path.rirTarget: deve essere intero o nullo');
      }
    }
    if (kb.parameterGroups.containsKey('trialLoad') &&
        !kb.rationales.any((r) => r.ruleId == 'TRIAL-LOAD')) {
      throw KbFormatException(
        'rationales.TRIAL-LOAD: manca ma esiste il gruppo trialLoad',
      );
    }
  }

  /// Enfasi: le sedute esistono, al massimo un posto per seduta, e nelle
  /// sedute full body ogni candidato ha una regione; serve la motivazione.
  static void _checkEmphases(KnowledgeBase kb) {
    if (kb.emphases.isEmpty) return;
    if (!kb.rationales.any((r) => r.ruleId == emphasisRuleId)) {
      throw KbFormatException(
        'rationales.$emphasisRuleId: manca ma esistono enfasi',
      );
    }
    final templates = {for (final t in kb.templates) t.id: t};
    for (final em in kb.emphases.values) {
      for (final e in em.placements.entries) {
        final t = templates[e.key];
        if (t == null) {
          throw KbFormatException(
            'emphasis.${em.id}.placements.${e.key}: template inesistente',
          );
        }
        final sessions = {for (final s in t.sessions) s.id: s};
        final seen = <String>{};
        for (final p in e.value) {
          final path = 'emphasis.${em.id}.placements.${e.key}.${p.session}';
          final session = sessions[p.session];
          if (session == null) {
            throw KbFormatException('$path: seduta inesistente');
          }
          if (!seen.add(p.session)) {
            throw KbFormatException('$path: più di un posto nella seduta');
          }
          if (session.focus != 'full_body') continue;
          for (final id in p.slot.candidates) {
            final ex = kb.exercises[id];
            if (ex == null) continue;
            final region = kb.patternRegions[ex.pattern];
            if (region != regionUpper && region != regionLower) {
              throw KbFormatException(
                '$path: il pattern ${ex.pattern} di $id non ha una regione '
                '($regionUpper o $regionLower) in patterns',
              );
            }
          }
        }
      }
    }
  }

  final String rulesVersion;
  final String? kbCommit;
  final double primaryWeight;
  final double secondaryWeight;
  final Map<String, KbExercise> exercises;
  final List<KbTemplate> templates;
  final List<KbPrescription> prescriptions;
  final Map<String, KbParameterGroup> parameterGroups;
  final List<KbRationale> rationales;
  final Map<String, KbPrinciple> principles;
  final Map<String, KbSource> sources;

  /// Regione (`upper` o `lower`) di ogni pattern di movimento.
  final Map<String, String> patternRegions;

  /// Enfasi per id (valore di `emphasis` del profilo).
  final Map<String, KbEmphasis> emphases;
}
