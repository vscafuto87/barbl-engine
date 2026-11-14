import '../contract/profile.dart';
import '../kb/models.dart';
import 'choose_exercises.dart';
import 'prescribe.dart';

/// Priorità di rimozione per ruolo: il numero più basso si toglie per primo.
/// I ruoli `main` non si tolgono mai; il finisher facoltativo (`core`) è il
/// primo a saltare se il suo ruolo conta nella durata (con
/// `countsTowardDuration: false` non si toglie mai, `P-CORE-FINISHER`). Sono nomi di ruolo del formato del
/// template, non numeri di dominio.
const Map<String, int> _removalOrder = {
  'core': 0,
  'accessory': 1,
  'secondary': 2,
};

/// Passo 2b: se una seduta supera `sessionDurationMin` secondo
/// [estimatedMinutes], toglie slot finché ci sta: prima il finisher facoltativo, poi gli isolamenti, poi i
/// complementari, sempre l'ultimo della seduta (`P-TIME-TRIM`); gli esercizi
/// principali restano. Un superset che resta con un solo slot diventa un
/// blocco singolo; un blocco vuoto sparisce. Se anche così la seduta non ci
/// sta, resta com'è e la prescrizione rifiuta il profilo per la durata.
List<ChosenSession> fitToDuration(
  List<ChosenSession> sessions,
  Profile profile,
  KbPrescription prescription,
) {
  return [for (final s in sessions) _fit(s, profile, prescription)];
}

ChosenSession _fit(
  ChosenSession session,
  Profile profile,
  KbPrescription prescription,
) {
  final blocks = [
    for (final b in session.blocks) ChosenBlock(b.type, b.label, [...b.slots]),
  ];
  int? total() {
    var sets = 0;
    for (final b in blocks) {
      for (final s in b.slots) {
        final role = prescription.roles[s.slot.role];
        if (role == null) return null;
        sets += role.timedSets;
      }
    }
    return sets;
  }

  while (true) {
    final sets = total();
    if (sets == null) return session;
    if (estimatedMinutes(sets, prescription) <= profile.sessionDurationMin) {
      break;
    }
    // L'ultimo slot, nell'ordine della seduta, del ruolo più sacrificabile.
    int? bestBlock;
    int? bestSlot;
    var bestRank = 1 << 30;
    for (var i = 0; i < blocks.length; i++) {
      for (var j = 0; j < blocks[i].slots.length; j++) {
        final roleId = blocks[i].slots[j].slot.role;
        final rank = _removalOrder[roleId];
        if (rank == null) continue;
        // Uno slot che non conta nella durata non si toglie per il tempo.
        if (!(prescription.roles[roleId]?.countsTowardDuration ?? true)) {
          continue;
        }
        if (rank <= bestRank) {
          bestRank = rank;
          bestBlock = i;
          bestSlot = j;
        }
      }
    }
    if (bestBlock == null || bestSlot == null) return session;
    blocks[bestBlock].slots.removeAt(bestSlot);
    if (blocks[bestBlock].slots.isEmpty) {
      blocks.removeAt(bestBlock);
    } else if (blocks[bestBlock].type == 'superset' &&
        blocks[bestBlock].slots.length == 1) {
      final only = blocks[bestBlock];
      blocks[bestBlock] = ChosenBlock('single', null, only.slots);
    }
  }
  return ChosenSession(session.session, blocks);
}
