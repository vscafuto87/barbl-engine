import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'choose_exercises.dart';
import 'result.dart';
import 'select_template.dart' show pickForExperience;

// Valore dell'obiettivo del profilo (formato del contratto).
const String _goalStrength = 'strength';

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
    this.fromEmphasis = false,
    this.fromExtension = false,
    this.optional = false,
    this.ruleIds = const [],
    this.lastSet,
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

  /// Vero per gli esercizi aggiunti dall'enfasi del profilo.
  final bool fromEmphasis;

  /// Vero per gli esercizi aggiunti per usare il tempo che resta.
  final bool fromExtension;

  /// Facoltativo per il ruolo (`optional` del piano 3.1).
  final bool optional;

  /// Regole del ruolo da citare nell'esercizio.
  final List<String> ruleIds;

  /// Tecnica dell'ultima serie (`lastSet` del piano 3.2), nulla se non c'è.
  final String? lastSet;
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

/// Colonna di recupero: per `upper_body` e `legs` la decide la seduta; per
/// `full_body` la decide la regione del pattern dell'esercizio scelto
/// (`kb/vocab/patterns.yaml`).
int _restFor(String focus, KbRole role, KbExercise exercise, KnowledgeBase kb) {
  switch (focus) {
    case 'upper_body':
      return role.restUpper;
    case 'legs':
      return role.restLower;
    case 'full_body':
      final region = kb.patternRegions[exercise.pattern];
      if (region == regionUpper) return role.restUpper;
      if (region == regionLower) return role.restLower;
      // `KnowledgeBase.fromJson` lo esclude per costruzione.
      throw StateError('pattern ${exercise.pattern} senza regione');
  }
  throw StateError('unsupported focus: $focus');
}

/// La prima prescrizione (per `id`) che vale per l'obiettivo del profilo,
/// con la stessa regola dei template per l'esperienza: prima quella che
/// dichiara l'esperienza del profilo, poi quella senza `experience`.
Result<KbPrescription> selectPrescription(Profile profile, KnowledgeBase kb) {
  final ordered = [
    for (final p in kb.prescriptions)
      if (p.appliesTo.contains(profile.goal)) p,
  ]..sort((a, b) => a.id.compareTo(b.id));
  final chosen = pickForExperience(ordered, profile, (p) => p.experience);
  if (chosen != null) return Ok(chosen);
  return Rejected(
    NotCovered(
      NotCoveredReason.goal,
      'no prescription for goal=${profile.goal}',
    ),
  );
}

/// Durata stimata di una seduta con [totalSets] serie e [techniqueMinutes]
/// minuti delle tecniche dell'ultima serie: è la stima con cui [prescribe]
/// controlla il limite del profilo (limite incluso).
int estimatedMinutes(
  int totalSets,
  KbPrescription prescription, [
  int techniqueMinutes = 0,
]) => totalSets * prescription.minutesPerSet + techniqueMinutes;

/// Tecnica dell'ultima serie di [slot] con l'esercizio scelto [exercise]:
/// quella dello slot, tolta se l'esercizio è un multiarticolare pesante
/// (`heavyCompound`) e, con l'obiettivo forza, se non è il cedimento.
String? effectiveLastSet(KbSlot slot, KbExercise exercise, Profile profile) {
  final lastSet = slot.lastSet;
  if (lastSet == null || exercise.heavyCompound) return null;
  if (profile.goal == _goalStrength && lastSet != lastSetFailure) return null;
  return lastSet;
}

/// Minuti in più della tecnica dell'ultima serie di [slot]
/// (`timeBudget.techniqueMinutes` della prescrizione; 0 se manca).
int slotTechniqueMinutes(
  ChosenSlot slot,
  Profile profile,
  KbPrescription prescription,
) {
  final lastSet = effectiveLastSet(slot.slot, slot.exercise, profile);
  if (lastSet == null) return 0;
  return prescription.techniqueMinutes[lastSet] ?? 0;
}

/// Minuti delle tecniche dell'ultima serie di tutti gli slot di [blocks].
int blocksTechniqueMinutes(
  Iterable<ChosenBlock> blocks,
  Profile profile,
  KbPrescription prescription,
) {
  var total = 0;
  for (final b in blocks) {
    for (final s in b.slots) {
      total += slotTechniqueMinutes(s, profile, prescription);
    }
  }
  return total;
}

/// Passo 3: serie, ripetizioni e recuperi dalla prescrizione dell'obiettivo,
/// poi controllo della durata (limite incluso). Le serie non si toccano: gli
/// slot in eccesso li ha già tolti `fitToDuration`.
Result<List<PrescribedSession>> prescribe(
  List<ChosenSession> chosen,
  Profile profile,
  KnowledgeBase kb,
) {
  final selected = selectPrescription(profile, kb);
  if (selected is Rejected<KbPrescription>) return Rejected(selected.reason);
  final prescription = (selected as Ok<KbPrescription>).value;

  final sessions = <PrescribedSession>[];
  for (final cs in chosen) {
    final focus = cs.session.focus;
    // Il focus dipende solo dal template, che `bundle` ha già validato: un
    // valore sconosciuto è un errore di programmazione, non un profilo.
    if (!supportedFocuses.contains(focus)) {
      throw StateError('unsupported focus: $focus');
    }
    var totalSets = 0;
    var techniqueMinutes = 0;
    final blocks = <PrescribedBlock>[];
    // Pattern già incontrati nella seduta, per il riscaldamento del primo
    // multiarticolare di ogni pattern.
    final seenPatterns = <String>{};
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
            : _restFor(focus, role, chosenSlot.exercise, kb);
        totalSets += role.timedSets;
        techniqueMinutes += slotTechniqueMinutes(
          chosenSlot,
          profile,
          prescription,
        );
        final firstOfPattern = seenPatterns.add(chosenSlot.exercise.pattern);
        final warmup = switch (role.warmupMode) {
          KbWarmupMode.always => true,
          KbWarmupMode.firstCompoundOfPattern =>
            firstOfPattern && chosenSlot.exercise.isCompound,
          KbWarmupMode.never => false,
        };
        exercises.add(
          PrescribedExercise(
            exercise: chosenSlot.exercise,
            role: slot.role,
            sets: role.sets,
            repsMin: override != null ? override.min : role.repsMin,
            repsMax: override != null ? override.max : role.repsMax,
            restSeconds: rest,
            warmup: warmup,
            rirFollowsMesocycle: role.rirFollowsMesocycle,
            askLoad: slot.askLoad,
            fromEmphasis: chosenSlot.fromEmphasis,
            fromExtension: chosenSlot.fromExtension,
            optional: role.optional,
            ruleIds: role.ruleIds,
            lastSet: effectiveLastSet(slot, chosenSlot.exercise, profile),
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
    final minutes = estimatedMinutes(totalSets, prescription, techniqueMinutes);
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
