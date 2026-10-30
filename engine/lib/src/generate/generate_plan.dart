import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import 'assemble_plan.dart';
import 'assign_loads.dart';
import 'choose_exercises.dart';
import 'prescribe.dart';
import 'result.dart';
import 'select_template.dart';

/// Genera il piano per un profilo (JSON del contratto) con la KB data.
/// Pura e deterministica; non lancia per un profilo.
GenerationResult generatePlan(
  Map<String, Object?> profileJson,
  KnowledgeBase kb,
) {
  final read = readProfile(profileJson);
  if (read is ProfileErrors) return InvalidProfile(read.errors);
  final profile = (read as ProfileOk).profile;

  final template = selectTemplate(profile, kb);
  if (template is Rejected<KbTemplate>) return template.reason;
  final selected = (template as Ok<KbTemplate>).value;

  final chosen = chooseExercises(selected, profile, kb);
  if (chosen is Rejected<List<ChosenSession>>) return chosen.reason;
  final chosenSessions = (chosen as Ok<List<ChosenSession>>).value;

  final prescribed = prescribe(chosenSessions, profile, kb);
  if (prescribed is Rejected<List<PrescribedSession>>) return prescribed.reason;
  final sessions = (prescribed as Ok<List<PrescribedSession>>).value;

  final loads = assignLoads(sessions, profile, kb);
  return Generated(
    assemblePlan(
      template: selected,
      profile: profile,
      sessions: sessions,
      loads: loads,
      kb: kb,
    ),
  );
}
