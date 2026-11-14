import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'result.dart';

/// Slot con l'esercizio scelto.
class ChosenSlot {
  ChosenSlot(
    this.slot,
    this.exercise, {
    this.fromEmphasis = false,
    this.fromExtension = false,
  });

  final KbSlot slot;
  final KbExercise exercise;

  /// Vero per gli slot aggiunti dall'enfasi del profilo.
  final bool fromEmphasis;

  /// Vero per gli slot aggiunti per usare il tempo che resta (estensioni).
  final bool fromExtension;
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
  final pool = availableCandidates(slot, profile, kb);
  return pool.isEmpty ? null : pool.first;
}

/// Candidati disponibili di [slot], nell'ordine del template. Per chi comincia
/// (`under_6_months`) gli esercizi tecnicamente impegnativi si escludono, a
/// meno che l'attrezzatura non offra altro: allora restano tutti
/// (`P-BEGINNER-SIMPLER`).
List<KbExercise> availableCandidates(
  KbSlot slot,
  Profile profile,
  KnowledgeBase kb,
) {
  final pool = [
    for (final id in slot.candidates)
      if (kb.exercises[id] case final exercise?)
        if (exercise.requires.every(profile.equipment.contains)) exercise,
  ];
  if (profile.experience != experienceBeginner) return pool;
  final simple = [
    for (final e in pool)
      if (!e.technicalDemandHigh) e,
  ];
  return simple.isNotEmpty ? simple : pool;
}

/// Quanti candidati di uno slot sono intercambiabili, secondo l'obiettivo: per
/// la forza la specificità vince (principale e complementari non si scambiano,
/// `P-STRENGTH-SPECIFICITY`), l'isolamento sì.
int equivalentWidth(KbSlot slot, Profile profile, int poolLength) {
  final allowed =
      profile.goal == 'strength' &&
          (slot.role == 'main' || slot.role == 'secondary')
      ? 1
      : slot.equivalent;
  return allowed < poolLength ? allowed : poolLength;
}

/// Uno dei primi [width] candidati di [pool], scelto in modo deterministico
/// da [hashKey] (`stableHash`); [pool] non è vuoto.
KbExercise pickFromPool(List<KbExercise> pool, int width, String hashKey) =>
    pool[width <= 1 ? 0 : stableHash(hashKey) % width];

/// Chiave stabile del profilo per l'assegnazione della variante. Non include
/// i carichi noti (l'onboarding genera il piano prima e dopo averli chiesti e
/// gli esercizi devono restare gli stessi), né l'obiettivo né l'enfasi: chi
/// cambia obiettivo o enfasi riceve gli stessi esercizi di isolamento, così il
/// confronto tra piani dello stesso profilo riguarda solo ciò che è cambiato.
String variantKey(Profile profile, {bool withDuration = true}) {
  final equipment = profile.equipment.toList()..sort();
  return [
    profile.gymType,
    equipment.join(','),
    profile.daysPerWeek,
    if (withDuration) profile.sessionDurationMin,
    profile.experience,
    if (profile.variantSeed != null) 'seed=${profile.variantSeed}',
  ].join('|');
}

/// FNV-1a a 32 bit più il finalizzatore di MurmurHash3 (i bit bassi di
/// FNV-1a da soli sono quasi solo la parità dei caratteri): deterministico e
/// uguale su ogni piattaforma.
int stableHash(String text) {
  var hash = 0x811c9dc5;
  for (final unit in text.codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  hash ^= hash >> 16;
  hash = (hash * 0x85ebca6b) & 0xffffffff;
  hash ^= hash >> 13;
  hash = (hash * 0xc2b2ae35) & 0xffffffff;
  hash ^= hash >> 16;
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
        // Per la forza la specificità vince: gli esercizi principali e
        // secondari non si scambiano (P-STRENGTH-SPECIFICITY); l'isolamento sì.
        final width = equivalentWidth(slot, profile, pool.length);
        final found = pool.isEmpty
            ? null
            : pickFromPool(
                pool,
                width,
                '${variantKey(profile)}|${session.id}|$slotIndex',
              );
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

/// Vero se ogni slot di [block] ha un ruolo facoltativo nella prescrizione
/// (il finisher dell'addome, `P-CORE-FINISHER`).
bool isOptionalBlock(ChosenBlock block, KbPrescription prescription) =>
    block.slots.isNotEmpty &&
    block.slots.every(
      (s) => prescription.roles[s.slot.role]?.optional ?? false,
    );

/// Quanti blocchi in coda a [blocks] sono facoltativi.
int optionalTailLength(List<ChosenBlock> blocks, KbPrescription prescription) {
  var n = 0;
  while (n < blocks.length &&
      isOptionalBlock(blocks[blocks.length - 1 - n], prescription)) {
    n++;
  }
  return n;
}

/// I blocchi di [blocks] con [extra] prima della coda facoltativa, così il
/// finisher resta l'ultimo della seduta. Con [dropTail] la coda si toglie.
List<ChosenBlock> insertBeforeOptionalTail(
  List<ChosenBlock> blocks,
  List<ChosenBlock> extra,
  KbPrescription prescription, {
  bool dropTail = false,
}) {
  final cut = blocks.length - optionalTailLength(blocks, prescription);
  return [
    ...blocks.sublist(0, cut),
    ...extra,
    if (!dropTail) ...blocks.sublist(cut),
  ];
}

/// Serie della coda facoltativa di [blocks] che contano nella durata.
int optionalTailSets(List<ChosenBlock> blocks, KbPrescription prescription) {
  var total = 0;
  final cut = blocks.length - optionalTailLength(blocks, prescription);
  for (final block in blocks.sublist(cut)) {
    for (final slot in block.slots) {
      total += prescription.roles[slot.slot.role]?.timedSets ?? 0;
    }
  }
  return total;
}
