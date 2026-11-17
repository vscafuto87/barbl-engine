import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'result.dart';

/// Passo 1: tra i template (per `id`) con i giorni del profilo e il suo
/// obiettivo, il primo che dichiara l'esperienza del profilo (`experience`);
/// se nessuno la dichiara, il primo senza `experience` (vale per tutti).
Result<KbTemplate> selectTemplate(Profile profile, KnowledgeBase kb) {
  final byDays = [
    for (final t in kb.templates)
      if (t.daysPerWeek == profile.daysPerWeek) t,
  ]..sort((a, b) => a.id.compareTo(b.id));
  if (byDays.isEmpty) {
    return Rejected(
      NotCovered(
        NotCoveredReason.days,
        'no template for daysPerWeek=${profile.daysPerWeek}',
      ),
    );
  }
  final byGoal = [
    for (final t in byDays)
      if (t.goals.contains(profile.goal)) t,
  ];
  final chosen = pickForExperience(byGoal, profile, (t) => t.experience);
  if (chosen != null) return Ok(chosen);
  return Rejected(
    NotCovered(
      NotCoveredReason.goal,
      'no template for daysPerWeek=${profile.daysPerWeek} goal=${profile.goal}',
    ),
  );
}

/// Il primo di [items] la cui esperienza contiene quella del profilo; se non
/// c'è, il primo senza esperienza dichiarata (vale per tutti); altrimenti null.
T? pickForExperience<T>(
  List<T> items,
  Profile profile,
  List<String> Function(T) experienceOf,
) {
  for (final item in items) {
    if (experienceOf(item).contains(profile.experience)) return item;
  }
  for (final item in items) {
    if (experienceOf(item).isEmpty) return item;
  }
  return null;
}
