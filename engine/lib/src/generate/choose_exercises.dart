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

/// Candidati disponibili di [slot], nell'ordine del template.
List<KbExercise> availableCandidates(
  KbSlot slot,
  Profile profile,
  KnowledgeBase kb,
) {
  return [
    for (final id in slot.candidates)
      if (kb.exercises[id] case final exercise?)
        if (exercise.requires.every(profile.equipment.contains)) exercise,
  ];
}

/// Chiave stabile del profilo per l'assegnazione della variante. Non include
/// i carichi noti: l'onboarding genera il piano prima e dopo averli chiesti e
/// gli esercizi devono restare gli stessi.
String variantKey(Profile profile) {
  final equipment = profile.equipment.toList()..sort();
  return [
    profile.goal,
    profile.gymType,
    equipment.join(','),
    profile.daysPerWeek,
    profile.sessionDurationMin,
    profile.experience,
    profile.emphasis.join(','),
  ].join('|');
}

/// FNV-1a a 32 bit: deterministico e uguale su ogni piattaforma.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Passo 2: in ogni slot il primo candidato disponibile ([firstAvailable]);
/// se lo slot dichiara `equivalent` N > 1, uno dei primi N disponibili, scelto
/// da `stableHash` di profilo, seduta e posizione: stesso profilo, stesso
/// piano; profili diversi, piani diversi.
Result<List<ChosenSession>> chooseExercises(
  KbTemplate template,
  Profile profile,
  KnowledgeBase kb,
) {
  final sessions = <ChosenSession>[];
  for (final session in template.sessions) {
    var sessionSlotIndex = 0;
    final blocks = <ChosenBlock>[];
    for (final block in session.blocks) {
      final slots = <ChosenSlot>[];
      for (final slot in block.slots) {
        final slotIndex = sessionSlotIndex++;
        final pool = availableCandidates(slot, profile, kb);
        final width = slot.equivalent < pool.length
            ? slot.equivalent
            : pool.length;
        final found = pool.isEmpty
            ? null
            : pool[width <= 1
                ? 0
                : stableHash(
                      '${variantKey(profile)}|${session.id}|'
                      '$slotIndex',
                    ) %
                    width];
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
