/// Il pacchetto non ha il formato atteso.
class KbFormatException implements Exception {
  KbFormatException(this.message);

  final String message;

  @override
  String toString() => 'KbFormatException: $message';
}
