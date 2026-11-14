import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'choose_exercises.dart';
import 'prescribe.dart';
import 'weekly_volume.dart';

/// Passo 2c: usa il tempo che resta. Ogni estensione del template, in ordine di
/// priorità (`extensions`), aggiunge in coda alla sua seduta un esercizio
/// (un blocco singolo) se:
///
/// 1. la seduta, con le serie in più, resta entro `sessionDurationMin` secondo
///    [estimatedMinutes] (il finisher facoltativo non conta,
///    `countsTowardDuration`, `P-CORE-FINISHER`);
/// 2. la seduta non ha già quel pattern (dal template, dall'enfasi o da
///    un'estensione precedente);
/// 3. dopo l'aggiunta nessun muscolo dell'esercizio supera il tetto di volume
///    settimanale della KB (`parameters/belowBand`, `P-VOL-BAND-CAP`);
/// 4. esiste un candidato disponibile che la seduta non ha già.
///
/// Altrimenti l'estensione si salta in silenzio. Il candidato è scelto tra
/// quelli che la settimana non usa ancora, se ce n'è uno, con la stessa regola
/// deterministica degli altri slot. Un template senza estensioni, o una KB
/// senza tetto, restituisce [sessions] invariate (`P-TIME-EXTEND`).
List<ChosenSession> extendToDuration(
  List<ChosenSession> sessions,
  KbTemplate template,
  Profile profile,
  KbPrescription prescription,
  KnowledgeBase kb,
) {
  final cap = kb.weeklyVolumeCap;
  if (template.extensions.isEmpty || cap == null) return sessions;
  final indexById = <String, int>{
    for (var i = 0; i < sessions.length; i++) sessions[i].session.id: i,
  };
  final totalSets = <int?>[
    for (final s in sessions) _sessionSets(s, prescription),
  ];
  final volume = weeklyVolume(sessions, prescription, kb);
  final added = <int, List<ChosenBlock>>{};
  final usedInWeek = <String>{
    for (final s in sessions)
      for (final b in s.blocks)
        for (final slot in b.slots) slot.exercise.id,
  };
  final inSession = <int, Set<String>>{};
  final patternsInSession = <int, Set<String>>{};
  for (var i = 0; i < sessions.length; i++) {
    inSession[i] = {
      for (final b in sessions[i].blocks)
        for (final slot in b.slots) slot.exercise.id,
    };
    patternsInSession[i] = {
      for (final b in sessions[i].blocks)
        for (final slot in b.slots) slot.exercise.pattern,
    };
  }

  // Le estensioni dei distretti scelti dalla persona (`emphasis`) passano per
  // prime, nell'ordine della KB: chi chiede più spazio per un distretto non
  // deve ricevere meno lavoro per quel distretto di chi non lo chiede.
  final emphasised = <String>{
    for (final id in profile.emphasis) ...?kb.emphases[id]?.muscles,
  };
  bool isEmphasised(KbEmphasisPlacement e) {
    final first = kb.exercises[e.slot.candidates.first];
    return first != null && emphasised.contains(first.primaryMuscle);
  }

  final order = <int>[
    for (var n = 0; n < template.extensions.length; n++)
      if (isEmphasised(template.extensions[n])) n,
    for (var n = 0; n < template.extensions.length; n++)
      if (!isEmphasised(template.extensions[n])) n,
  ];
  for (final n in order) {
    final extension = template.extensions[n];
    final i = indexById[extension.session];
    if (i == null) continue;
    final current = totalSets[i];
    if (current == null) continue;
    final role = prescription.roles[extension.slot.role];
    if (role == null) continue;
    if (estimatedMinutes(current + role.timedSets, prescription) >
        profile.sessionDurationMin) {
      continue;
    }
    if (patternsInSession[i]!.contains(extension.slot.pattern)) continue;
    final pool = [
      for (final c in availableCandidates(extension.slot, profile, kb))
        if (!inSession[i]!.contains(c.id)) c,
    ];
    if (pool.isEmpty) continue;
    final fresh = [
      for (final c in pool)
        if (!usedInWeek.contains(c.id)) c,
    ];
    final unused = fresh.isNotEmpty ? fresh : pool;
    // Tra i candidati, quelli che allenano anche un distretto scelto dalla
    // persona (`emphasis`) passano per primi: più tempo per le estensioni non
    // deve dare a chi chiede un distretto meno lavoro per quel distretto.
    final helpsEmphasis = [
      for (final c in unused)
        if ([c.primaryMuscle, ...c.secondaryMuscles].any(emphasised.contains))
          c,
    ];
    final choices = helpsEmphasis.isNotEmpty ? helpsEmphasis : unused;
    final width = equivalentWidth(extension.slot, profile, choices.length);
    final exercise = pickFromPool(
      choices,
      width,
      // Senza la durata: con più tempo lo stesso profilo riceve le stesse
      // scelte e in più le estensioni che prima non entravano.
      '${variantKey(profile, withDuration: false)}|ext|'
      '${sessions[i].session.id}|$n',
    );
    final next = Map<String, double>.of(volume);
    addSets(next, exercise, role.sets, kb);
    final muscles = [exercise.primaryMuscle, ...exercise.secondaryMuscles];
    if (muscles.any((m) => (next[m] ?? 0) > cap)) continue;

    volume
      ..clear()
      ..addAll(next);
    totalSets[i] = current + role.timedSets;
    inSession[i]!.add(exercise.id);
    patternsInSession[i]!.add(exercise.pattern);
    usedInWeek.add(exercise.id);
    added
        .putIfAbsent(i, () => <ChosenBlock>[])
        .add(
          ChosenBlock('single', null, [
            ChosenSlot(extension.slot, exercise, fromExtension: true),
          ]),
        );
  }
  if (added.isEmpty) return sessions;
  return [
    for (var i = 0; i < sessions.length; i++)
      added[i] == null
          ? sessions[i]
          : ChosenSession(
              sessions[i].session,
              insertBeforeOptionalTail(
                sessions[i].blocks,
                added[i]!,
                prescription,
              ),
            ),
  ];
}

/// Serie di una seduta con la prescrizione data; null se un ruolo manca (la
/// prescrizione rifiuterà il profilo).
int? _sessionSets(ChosenSession session, KbPrescription prescription) {
  var total = 0;
  for (final block in session.blocks) {
    for (final slot in block.slots) {
      final role = prescription.roles[slot.slot.role];
      if (role == null) return null;
      total += role.timedSets;
    }
  }
  return total;
}
