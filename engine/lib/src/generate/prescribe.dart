import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'choose_exercises.dart';
import 'result.dart';

/// Esercizio con la prescrizione applicata.
class PrescribedExercise {
  PrescribedExercise({
    required this.exercise,
    required this.role,
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.restSeconds,
    required this.warmup,
    required this.rirFollowsMesocycle,
    required this.askLoad,
  });

  final KbExercise exercise;
  final String role;
  final int sets;
  final int repsMin;
  final int repsMax;

  /// Nullo per gli esercizi di un superset: il recupero è del blocco.
  final int? restSeconds;
  final bool warmup;
  final bool rirFollowsMesocycle;
  final bool askLoad;
}

/// Blocco con la prescrizione applicata.
class PrescribedBlock {
  PrescribedBlock(this.type, this.label, this.restSeconds, this.exercises);

  final String type;
  final String? label;

  /// Solo per i superset.
  final int? restSeconds;
  final List<PrescribedExercise> exercises;
}

/// Seduta con la prescrizione applicata e la durata stimata.
class PrescribedSession {
  PrescribedSession({
    required this.id,
    required this.nameIt,
    required this.focus,
    required this.estimatedDurationMin,
    required this.blocks,
  });

  final String id;
  final String nameIt;
  final String focus;
  final int estimatedDurationMin;
  final List<PrescribedBlock> blocks;
}

/// Passo 3: serie, ripetizioni e recuperi dalla prescrizione dell'obiettivo,
/// poi controllo della durata (limite incluso). Il motore non toglie serie.
Result<List<PrescribedSession>> prescribe(
  List<ChosenSession> chosen,
  Profile profile,
  KnowledgeBase kb,
) {
  final ordered = [...kb.prescriptions]..sort((a, b) => a.id.compareTo(b.id));
  KbPrescription? prescription;
  for (final p in ordered) {
    if (p.appliesTo.contains(profile.goal)) {
      prescription = p;
      break;
    }
  }
  if (prescription == null) {
    return Rejected(
      NotCovered(
        NotCoveredReason.goal,
        'no prescription for goal=${profile.goal}',
      ),
    );
  }

  final sessions = <PrescribedSession>[];
  for (final cs in chosen) {
    final focus = cs.session.focus;
    // Il focus dipende solo dal template, che `bundle` ha già validato: un
    // valore sconosciuto è un errore di programmazione, non un profilo.
    if (focus != 'upper_body' && focus != 'legs') {
      throw StateError('unsupported focus: $focus');
    }
    var totalSets = 0;
    final blocks = <PrescribedBlock>[];
    for (final cb in cs.blocks) {
      final isSuperset = cb.type == 'superset';
      final exercises = <PrescribedExercise>[];
      for (final chosenSlot in cb.slots) {
        final slot = chosenSlot.slot;
        final role = prescription.roles[slot.role];
        if (role == null) {
          // Dipende dall'obiettivo del profilo: è un rifiuto, non un'eccezione.
          return Rejected(
            NotCovered(
              NotCoveredReason.goal,
              'role ${slot.role} missing in prescription ${prescription.id} '
              '(session ${cs.session.id})',
            ),
          );
        }
        final override = slot.repsOverride;
        final int? rest = isSuperset
            ? null
            : (focus == 'upper_body' ? role.restUpper : role.restLower);
        totalSets += role.sets;
        exercises.add(
          PrescribedExercise(
            exercise: chosenSlot.exercise,
            role: slot.role,
            sets: role.sets,
            repsMin: override != null ? override.min : role.repsMin,
            repsMax: override != null ? override.max : role.repsMax,
            restSeconds: rest,
            warmup: role.warmup,
            rirFollowsMesocycle: role.rirFollowsMesocycle,
            askLoad: slot.askLoad,
          ),
        );
      }
      blocks.add(
        PrescribedBlock(
          cb.type,
          cb.label,
          isSuperset ? prescription.supersetRestSeconds : null,
          exercises,
        ),
      );
    }
    final minutes = totalSets * prescription.minutesPerSet;
    if (minutes > profile.sessionDurationMin) {
      return Rejected(
        NotCovered(
          NotCoveredReason.duration,
          'session=${cs.session.id} estimated=$minutes min '
          'exceeds limit=${profile.sessionDurationMin} min',
        ),
      );
    }
    sessions.add(
      PrescribedSession(
        id: cs.session.id,
        nameIt: cs.session.nameIt,
        focus: focus,
        estimatedDurationMin: minutes,
        blocks: blocks,
      ),
    );
  }
  return Ok(sessions);
}
