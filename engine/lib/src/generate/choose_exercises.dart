import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'result.dart';

/// Slot con l'esercizio scelto.
class ChosenSlot {
  ChosenSlot(this.slot, this.exercise, {this.fromEmphasis = false});

  final KbSlot slot;
  final KbExercise exercise;

  /// Vero per gli slot aggiunti dall'enfasi del profilo.
  final bool fromEmphasis;
}

/// Blocco con gli esercizi scelti.
class ChosenBlock {
  ChosenBlock(this.type, this.label, this.slots);

  final String type;
  final String? label;
  final List<ChosenSlot> slots;
}

/// Seduta con gli esercizi scelti.
class ChosenSession {
  ChosenSession(this.session, this.blocks);

  final KbSession session;
  final List<ChosenBlock> blocks;
}

/// Il primo candidato di [slot] (nell'ordine) le cui attrezzature richieste
/// sono tutte nel profilo, o null. I valori sconosciuti del profilo non
/// corrispondono a nessuna richiesta e sono ignorati.
KbExercise? firstAvailable(KbSlot slot, Profile profile, KnowledgeBase kb) {
  for (final id in slot.candidates) {
    final exercise = kb.exercises[id];
    if (exercise == null) continue;
    if (exercise.requires.every(profile.equipment.contains)) return exercise;
  }
  return null;
}

/// Passo 2: in ogni slot il primo candidato disponibile ([firstAvailable]).
Result<List<ChosenSession>> chooseExercises(
  KbTemplate template,
  Profile profile,
  KnowledgeBase kb,
) {
  final sessions = <ChosenSession>[];
  for (final session in template.sessions) {
    final blocks = <ChosenBlock>[];
    for (final block in session.blocks) {
      final slots = <ChosenSlot>[];
      for (final slot in block.slots) {
        final found = firstAvailable(slot, profile, kb);
        if (found == null) {
          return Rejected(
            NotCovered(
              NotCoveredReason.equipment,
              'no exercise available for session=${session.id} '
              'pattern=${slot.pattern}',
            ),
          );
        }
        slots.add(ChosenSlot(slot, found));
      }
      blocks.add(ChosenBlock(block.type, block.label, slots));
    }
    sessions.add(ChosenSession(session, blocks));
  }
  return Ok(sessions);
}
