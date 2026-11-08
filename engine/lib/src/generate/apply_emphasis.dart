import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'choose_exercises.dart';
import 'prescribe.dart';

/// Serie di una seduta con la prescrizione data; null se un ruolo manca (la
/// prescrizione rifiuterà il profilo).
int? _sessionSets(ChosenSession session, KbPrescription prescription) {
  var total = 0;
  for (final block in session.blocks) {
    for (final slot in block.slots) {
      final role = prescription.roles[slot.slot.role];
      if (role == null) return null;
      total += role.sets;
    }
  }
  return total;
}

/// Passo 2b: aggiunge in coda alle sedute gli slot delle enfasi del profilo
/// (`kb/emphasis/`), ciascuno in un blocco singolo.
///
/// Gli slot si valutano nell'ordine di `emphasis` del profilo e poi in quello
/// dei posti del template. Uno slot entra solo se la seduta, con le sue serie,
/// resta entro `sessionDurationMin` secondo [estimatedMinutes]; altrimenti si
/// salta, come si salta uno slot senza candidati disponibili, un'enfasi senza
/// file o un template senza posti. Senza enfasi restituisce [sessions].
List<ChosenSession> applyEmphasis(
  List<ChosenSession> sessions,
  KbTemplate template,
  Profile profile,
  KbPrescription prescription,
  KnowledgeBase kb,
) {
  if (profile.emphasis.isEmpty) return sessions;
  final indexById = <String, int>{
    for (var i = 0; i < sessions.length; i++) sessions[i].session.id: i,
  };
  final sets = [for (final s in sessions) _sessionSets(s, prescription)];
  final added = <int, List<ChosenBlock>>{};
  for (final id in profile.emphasis) {
    final placements = kb.emphases[id]?.placements[template.id];
    if (placements == null) continue;
    for (final placement in placements) {
      final i = indexById[placement.session];
      if (i == null) continue;
      final current = sets[i];
      if (current == null) continue;
      final role = prescription.roles[placement.slot.role];
      if (role == null) continue;
      // Il primo candidato disponibile che la seduta non ha già (anche da
      // un'enfasi precedente): l'enfasi non ripete un esercizio.
      final used = <String>{
        for (final block in sessions[i].blocks)
          for (final slot in block.slots) slot.exercise.id,
        for (final block in added[i] ?? const <ChosenBlock>[])
          for (final slot in block.slots) slot.exercise.id,
      };
      KbExercise? exercise;
      for (final candidate in availableCandidates(
        placement.slot,
        profile,
        kb,
      )) {
        if (!used.contains(candidate.id)) {
          exercise = candidate;
          break;
        }
      }
      if (exercise == null) continue;
      final total = current + role.sets;
      if (estimatedMinutes(total, prescription) > profile.sessionDurationMin) {
        continue;
      }
      sets[i] = total;
      added
          .putIfAbsent(i, () => <ChosenBlock>[])
          .add(
            ChosenBlock('single', null, [
              ChosenSlot(placement.slot, exercise, fromEmphasis: true),
            ]),
          );
    }
  }
  if (added.isEmpty) return sessions;
  return [
    for (var i = 0; i < sessions.length; i++)
      added[i] == null
          ? sessions[i]
          : ChosenSession(sessions[i].session, [
              ...sessions[i].blocks,
              ...added[i]!,
            ]),
  ];
}
