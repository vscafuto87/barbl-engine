/// Esiti della generazione e risultato di un passo.
library;

/// Esito di `generatePlan`.
sealed class GenerationResult {
  const GenerationResult();
}

/// Piano generato, nella forma JSON del contratto.
final class Generated extends GenerationResult {
  Generated(this.plan);

  final Map<String, Object?> plan;
}

/// Profilo non valido: ogni voce indica percorso e motivo.
final class InvalidProfile extends GenerationResult {
  InvalidProfile(this.errors);

  final List<String> errors;
}

/// Motivo per cui la KB non copre il profilo.
enum NotCoveredReason { days, goal, equipment, duration }

/// La KB non copre il profilo.
final class NotCovered extends GenerationResult {
  NotCovered(this.reason, this.detail);

  final NotCoveredReason reason;

  /// Testo tecnico breve, in inglese.
  final String detail;
}

/// Risultato di un passo: valore o rifiuto.
sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  Ok(this.value);

  final T value;
}

final class Rejected<T> extends Result<T> {
  Rejected(this.reason);

  final NotCovered reason;
}
