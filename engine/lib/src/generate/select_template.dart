import '../contract/profile.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart';
import 'result.dart';

/// Passo 1: il primo template (per `id`) con i giorni del profilo e il suo obiettivo.
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
  for (final t in byDays) {
    if (t.goals.contains(profile.goal)) {
      return Ok(t);
    }
  }
  return Rejected(
    NotCovered(
      NotCoveredReason.goal,
      'no template for daysPerWeek=${profile.daysPerWeek} goal=${profile.goal}',
    ),
  );
}
