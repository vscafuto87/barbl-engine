import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'choose_exercises.dart';

/// Serie settimanali per muscolo delle [sessions] con la prescrizione data,
/// contate in modo frazionario (`setWeights` della KB, `P-VOL-FRACTIONAL`): il
/// muscolo primario conta per intero, i secondari a metà. Uno slot il cui
/// ruolo manca nella prescrizione non conta (la prescrizione rifiuterà il
/// profilo).
Map<String, double> weeklyVolume(
  Iterable<ChosenSession> sessions,
  KbPrescription prescription,
  KnowledgeBase kb,
) {
  final totals = <String, double>{};
  for (final session in sessions) {
    for (final block in session.blocks) {
      for (final slot in block.slots) {
        final role = prescription.roles[slot.slot.role];
        if (role == null) continue;
        addSets(totals, slot.exercise, role.sets, kb);
      }
    }
  }
  return totals;
}

/// Aggiunge a [totals] le serie frazionarie di [sets] serie di [exercise].
void addSets(
  Map<String, double> totals,
  KbExercise exercise,
  int sets,
  KnowledgeBase kb,
) {
  totals[exercise.primaryMuscle] =
      (totals[exercise.primaryMuscle] ?? 0) + sets * kb.primaryWeight;
  for (final m in exercise.secondaryMuscles) {
    totals[m] = (totals[m] ?? 0) + sets * kb.secondaryWeight;
  }
}
