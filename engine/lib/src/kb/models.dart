import 'reader.dart';

/// Focus di seduta che la generazione sa trattare (colonna di recupero).
const Set<String> supportedFocuses = {'upper_body', 'legs', 'full_body'};

/// Regioni dei pattern (`kb/vocab/patterns.yaml`) che scelgono la colonna di
/// recupero di una seduta full body.
const String regionUpper = 'upper';
const String regionLower = 'lower';

/// Regola che il motore cita negli esercizi aggiunti per enfasi.
const String emphasisRuleId = 'EMPHASIS';

/// Esercizio della KB.
class KbExercise {
  const KbExercise({
    required this.id,
    required this.nameIt,
    required this.nameEn,
    required this.equipment,
    required this.requires,
    required this.pattern,
    required this.primaryMuscle,
    required this.secondaryMuscles,
    required this.stepKg,
    required this.whenLoadUnknown,
    this.substitutes = const [],
  });

  factory KbExercise.fromJson(Map<String, Object?> json, String path) {
    final muscles = mapAt(json, 'muscles', path);
    final loading = mapAt(json, 'loading', path);
    return KbExercise(
      id: stringAt(json, 'id', path),
      nameIt: stringAt(mapAt(json, 'name', path), 'it', '$path.name'),
      nameEn: stringAt(mapAt(json, 'name', path), 'en', '$path.name'),
      equipment: stringAt(json, 'equipment', path),
      requires: stringsAt(json, 'requires', path),
      pattern: stringAt(json, 'pattern', path),
      primaryMuscle: stringAt(muscles, 'primary', '$path.muscles'),
      secondaryMuscles: stringsOrEmpty(muscles, 'secondary', '$path.muscles'),
      stepKg: doubleOrNull(loading, 'stepKg', '$path.loading'),
      whenLoadUnknown: stringAt(loading, 'whenLoadUnknown', '$path.loading'),
      substitutes: stringsOrEmpty(json, 'substitutes', path),
    );
  }

  final String id;
  final String nameIt;
  final String nameEn;
  final String equipment;
  final List<String> requires;
  final String pattern;
  final String primaryMuscle;
  final List<String> secondaryMuscles;

  /// Esercizi che possono sostituirlo, in ordine di preferenza.
  final List<String> substitutes;

  /// Passo di carico in kg; nullo per gli esercizi a corpo libero.
  final double? stepKg;
  final String whenLoadUnknown;
}

/// Slot di un blocco: un pattern, un ruolo e i candidati in ordine di preferenza.
class KbSlot {
  const KbSlot({
    required this.pattern,
    required this.role,
    required this.candidates,
    required this.askLoad,
    required this.repsOverride,
    this.equivalent = 1,
  });

  factory KbSlot.fromJson(Map<String, Object?> json, String path) {
    final override = json['repsOverride'];
    ({int min, int max})? repsOverride;
    if (override != null) {
      final m = asMap(override, '$path.repsOverride');
      repsOverride = (
        min: intAt(m, 'min', '$path.repsOverride'),
        max: intAt(m, 'max', '$path.repsOverride'),
      );
    }
    return KbSlot(
      pattern: stringAt(json, 'pattern', path),
      role: stringAt(json, 'role', path),
      candidates: stringsAt(json, 'candidates', path),
      askLoad: boolOr(json, 'askLoad', path, false),
      repsOverride: repsOverride,
      equivalent: json['equivalent'] == null
          ? 1
          : intAt(json, 'equivalent', path),
    );
  }

  /// Quanti dei primi candidati disponibili sono intercambiabili: tra questi
  /// il motore ne assegna uno in modo deterministico (vedi `chooseExercises`).
  /// 1 = vale il primo disponibile.
  final int equivalent;

  final String pattern;
  final String role;
  final List<String> candidates;
  final bool askLoad;
  final ({int min, int max})? repsOverride;
}

/// Blocco di una seduta: `single` o `superset`.
class KbBlock {
  const KbBlock({required this.type, required this.label, required this.slots});

  factory KbBlock.fromJson(Map<String, Object?> json, String path) {
    final slots = listAt(json, 'slots', path);
    return KbBlock(
      type: stringAt(json, 'type', path),
      label: stringOrNull(json, 'label', path),
      slots: [
        for (var i = 0; i < slots.length; i++)
          KbSlot.fromJson(asMap(slots[i], '$path.slots[$i]'), '$path.slots[$i]'),
      ],
    );
  }

  final String type;
  final String? label;
  final List<KbSlot> slots;
}

/// Seduta di un template.
class KbSession {
  const KbSession({
    required this.id,
    required this.nameIt,
    required this.focus,
    required this.blocks,
  });

  factory KbSession.fromJson(Map<String, Object?> json, String path) {
    final blocks = listAt(json, 'blocks', path);
    return KbSession(
      id: stringAt(json, 'id', path),
      nameIt: stringAt(mapAt(json, 'name', path), 'it', '$path.name'),
      focus: stringAt(json, 'focus', path),
      blocks: [
        for (var i = 0; i < blocks.length; i++)
          KbBlock.fromJson(
            asMap(blocks[i], '$path.blocks[$i]'),
            '$path.blocks[$i]',
          ),
      ],
    );
  }

  final String id;
  final String nameIt;
  final String focus;
  final List<KbBlock> blocks;
}

/// Split con le sue sedute.
class KbTemplate {
  const KbTemplate({
    required this.id,
    required this.split,
    required this.daysPerWeek,
    required this.goals,
    required this.defaultSchedule,
    required this.sessions,
  });

  factory KbTemplate.fromJson(Map<String, Object?> json, String path) {
    final schedule = mapAt(json, 'defaultSchedule', path);
    final sessions = listAt(json, 'sessions', path);
    return KbTemplate(
      id: stringAt(json, 'id', path),
      split: stringAt(json, 'split', path),
      daysPerWeek: intAt(json, 'daysPerWeek', path),
      goals: stringsAt(json, 'goals', path),
      defaultSchedule: {
        for (final e in schedule.entries)
          e.key: asString(e.value, '$path.defaultSchedule.${e.key}'),
      },
      sessions: [
        for (var i = 0; i < sessions.length; i++)
          KbSession.fromJson(
            asMap(sessions[i], '$path.sessions[$i]'),
            '$path.sessions[$i]',
          ),
      ],
    );
  }

  final String id;
  final String split;
  final int daysPerWeek;
  final List<String> goals;
  final Map<String, String> defaultSchedule;
  final List<KbSession> sessions;
}

/// Posto di un'enfasi in un template: la seduta e lo slot da aggiungere in
/// coda.
class KbEmphasisPlacement {
  const KbEmphasisPlacement({required this.session, required this.slot});

  factory KbEmphasisPlacement.fromJson(Map<String, Object?> json, String path) {
    return KbEmphasisPlacement(
      session: stringAt(json, 'session', path),
      slot: KbSlot.fromJson(mapAt(json, 'slot', path), '$path.slot'),
    );
  }

  final String session;
  final KbSlot slot;
}

/// Lavoro mirato su un distretto (`emphasis` del profilo): per id di template
/// i posti, nell'ordine della KB. Un template senza voce non cambia.
class KbEmphasis {
  const KbEmphasis({
    required this.id,
    required this.muscles,
    required this.placements,
  });

  factory KbEmphasis.fromJson(Map<String, Object?> json, String path) {
    final raw = mapAt(json, 'placements', path);
    final placements = <String, List<KbEmphasisPlacement>>{};
    for (final e in raw.entries) {
      final tpath = '$path.placements.${e.key}';
      final list = asList(e.value, tpath);
      placements[e.key] = [
        for (var i = 0; i < list.length; i++)
          KbEmphasisPlacement.fromJson(asMap(list[i], '$tpath[$i]'), '$tpath[$i]'),
      ];
    }
    return KbEmphasis(
      id: stringAt(json, 'id', path),
      muscles: stringsAt(json, 'muscles', path),
      placements: placements,
    );
  }

  final String id;

  /// Muscoli del distretto.
  final List<String> muscles;

  /// Id di template -> posti.
  final Map<String, List<KbEmphasisPlacement>> placements;
}

/// Prescrizione di un ruolo: serie, ripetizioni e recuperi.
class KbRole {
  const KbRole({
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restUpper,
    required this.restLower,
    required this.rirFollowsMesocycle,
    required this.warmup,
  });

  factory KbRole.fromJson(Map<String, Object?> json, String path) {
    final reps = mapAt(json, 'reps', path);
    final rest = mapAt(json, 'restSeconds', path);
    return KbRole(
      sets: intAt(json, 'sets', path),
      repsMin: intAt(reps, 'min', '$path.reps'),
      repsMax: intAt(reps, 'max', '$path.reps'),
      restUpper: intAt(rest, 'upper', '$path.restSeconds'),
      restLower: intAt(rest, 'lower', '$path.restSeconds'),
      rirFollowsMesocycle: boolOr(json, 'rirFollowsMesocycle', path, false),
      warmup: boolOr(json, 'warmup', path, false),
    );
  }

  final int sets;
  final int repsMin;
  final int repsMax;
  final int restUpper;
  final int restLower;
  final bool rirFollowsMesocycle;
  final bool warmup;
}

/// Prescrizione per obiettivo.
class KbPrescription {
  const KbPrescription({
    required this.id,
    required this.appliesTo,
    required this.roles,
    required this.supersetRestSeconds,
    required this.minutesPerSet,
  });

  factory KbPrescription.fromJson(Map<String, Object?> json, String path) {
    final roles = mapAt(json, 'roles', path);
    return KbPrescription(
      id: stringAt(json, 'id', path),
      appliesTo: stringsAt(json, 'appliesTo', path),
      roles: {
        for (final e in roles.entries)
          e.key: KbRole.fromJson(
            asMap(e.value, '$path.roles.${e.key}'),
            '$path.roles.${e.key}',
          ),
      },
      supersetRestSeconds: intAt(json, 'supersetRestSeconds', path),
      minutesPerSet: intAt(
        mapAt(json, 'timeBudget', path),
        'minutesPerSet',
        '$path.timeBudget',
      ),
    );
  }

  final String id;
  final List<String> appliesTo;
  final Map<String, KbRole> roles;
  final int supersetRestSeconds;
  final int minutesPerSet;
}

/// Gruppo del blocco `parameters` del contratto (o il mesociclo).
class KbParameterGroup {
  const KbParameterGroup({
    required this.group,
    required this.target,
    required this.ruleId,
    required this.values,
    required this.provisional,
    required this.principles,
    required this.engineConstraints,
  });

  factory KbParameterGroup.fromJson(Map<String, Object?> json, String path) {
    return KbParameterGroup(
      group: stringAt(json, 'group', path),
      target: stringAt(json, 'target', path),
      ruleId: stringOrNull(json, 'ruleId', path),
      values: mapAt(json, 'values', path),
      provisional: boolAt(json, 'provisional', path),
      principles: stringsOrEmpty(json, 'principles', path),
      engineConstraints: mapOrEmpty(json, 'engineConstraints', path),
    );
  }

  final String group;
  final String target;
  final String? ruleId;
  final Map<String, Object?> values;
  final bool provisional;
  final List<String> principles;
  final Map<String, Object?> engineConstraints;
}

/// Testo del «Perché?» per una regola.
class KbRationale {
  const KbRationale({
    required this.ruleId,
    required this.key,
    required this.level,
    required this.textIt,
    required this.textEn,
    required this.exampleValues,
    required this.sourcesFrom,
    required this.principles,
    required this.everyExercise,
  });

  factory KbRationale.fromJson(Map<String, Object?> json, String path) {
    final text = mapAt(json, 'text', path);
    return KbRationale(
      ruleId: stringAt(json, 'ruleId', path),
      key: stringAt(json, 'key', path),
      level: stringOrNull(json, 'level', path) ?? 'set',
      textIt: stringAt(text, 'it', '$path.text'),
      textEn: stringAt(text, 'en', '$path.text'),
      exampleValues: mapOrEmpty(json, 'exampleValues', path),
      sourcesFrom: stringOrNull(json, 'sourcesFrom', path),
      principles: stringsOrEmpty(json, 'principles', path),
      everyExercise: boolOr(json, 'everyExercise', path, false),
    );
  }

  final String ruleId;
  final String key;
  final String level;
  final String textIt;
  final String textEn;
  final Map<String, Object?> exampleValues;
  final String? sourcesFrom;
  final List<String> principles;
  final bool everyExercise;
}

/// Riferimento di un principio a una fonte.
class KbSourceRef {
  const KbSourceRef({
    required this.id,
    required this.pages,
    required this.access,
  });

  factory KbSourceRef.fromJson(Map<String, Object?> json, String path) {
    final pages = json['pages'];
    return KbSourceRef(
      id: stringAt(json, 'id', path),
      pages: pages == null
          ? const []
          : [
              for (final p in asList(pages, '$path.pages'))
                p is num ? p.toString() : asString(p, '$path.pages'),
            ],
      access: stringOrNull(json, 'access', path),
    );
  }

  final String id;
  final List<String> pages;
  final String? access;
}

/// Principio: serve al «Perché?» per risalire alle fonti.
class KbPrinciple {
  const KbPrinciple({
    required this.id,
    required this.sources,
    required this.refs,
  });

  factory KbPrinciple.fromJson(Map<String, Object?> json, String path) {
    final raw = json['sources'] == null
        ? const <Object?>[]
        : listAt(json, 'sources', path);
    final refs = [
      for (var i = 0; i < raw.length; i++)
        KbSourceRef.fromJson(
          asMap(raw[i], '$path.sources[$i]'),
          '$path.sources[$i]',
        ),
    ];
    return KbPrinciple(
      id: stringAt(json, 'id', path),
      sources: [for (final r in refs) r.id],
      refs: refs,
    );
  }

  final String id;

  /// Identificativi delle fonti, nell'ordine del principio.
  final List<String> sources;

  /// Riferimenti completi (fonte, pagine, accesso).
  final List<KbSourceRef> refs;
}

/// Fonte bibliografica.
class KbSource {
  const KbSource({
    required this.id,
    required this.tier,
    required this.title,
    required this.reference,
    required this.url,
    required this.use,
    required this.type,
  });

  factory KbSource.fromJson(Map<String, Object?> json, String path) {
    return KbSource(
      id: stringAt(json, 'id', path),
      tier: intAt(json, 'tier', path),
      title: stringAt(json, 'title', path),
      reference: stringOrNull(json, 'reference', path) ?? '',
      url: stringOrNull(json, 'url', path),
      use: stringAt(json, 'use', path),
      type: stringAt(json, 'type', path),
    );
  }

  final String id;
  final int tier;
  final String title;
  final String reference;
  final String? url;
  final String use;
  final String type;
}
