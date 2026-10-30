import 'knowledge_base.dart';

/// Lettura tipizzata dei dati JSON del pacchetto: ogni errore diventa una
/// [KbFormatException] con il percorso del campo.
Map<String, Object?> asMap(Object? v, String path) {
  if (v is Map) {
    return {for (final e in v.entries) e.key.toString(): e.value};
  }
  throw KbFormatException('$path: attesa una mappa');
}

List<Object?> asList(Object? v, String path) {
  if (v is List) return List<Object?>.from(v);
  throw KbFormatException('$path: attesa una lista');
}

String asString(Object? v, String path) {
  if (v is String) return v;
  throw KbFormatException('$path: attesa una stringa');
}

int asInt(Object? v, String path) {
  if (v is num && v == v.truncate()) return v.toInt();
  throw KbFormatException('$path: atteso un intero');
}

double asDouble(Object? v, String path) {
  if (v is num) return v.toDouble();
  throw KbFormatException('$path: atteso un numero');
}

bool asBool(Object? v, String path) {
  if (v is bool) return v;
  throw KbFormatException('$path: atteso un booleano');
}

/// Valore obbligatorio di [key] in [m]; [path] è il percorso della mappa.
Object? need(Map<String, Object?> m, String key, String path) {
  if (!m.containsKey(key) || m[key] == null) {
    throw KbFormatException('$path.$key: campo mancante');
  }
  return m[key];
}

Map<String, Object?> mapAt(Map<String, Object?> m, String key, String path) =>
    asMap(need(m, key, path), '$path.$key');

List<Object?> listAt(Map<String, Object?> m, String key, String path) =>
    asList(need(m, key, path), '$path.$key');

String stringAt(Map<String, Object?> m, String key, String path) =>
    asString(need(m, key, path), '$path.$key');

int intAt(Map<String, Object?> m, String key, String path) =>
    asInt(need(m, key, path), '$path.$key');

double doubleAt(Map<String, Object?> m, String key, String path) =>
    asDouble(need(m, key, path), '$path.$key');

bool boolAt(Map<String, Object?> m, String key, String path) =>
    asBool(need(m, key, path), '$path.$key');

List<String> stringsAt(Map<String, Object?> m, String key, String path) {
  final list = listAt(m, key, path);
  return [
    for (var i = 0; i < list.length; i++) asString(list[i], '$path.$key[$i]'),
  ];
}

/// Variante facoltativa: assente o nulla vale [orElse].
bool boolOr(Map<String, Object?> m, String key, String path, bool orElse) =>
    m[key] == null ? orElse : asBool(m[key], '$path.$key');

String? stringOrNull(Map<String, Object?> m, String key, String path) =>
    m[key] == null ? null : asString(m[key], '$path.$key');

List<String> stringsOrEmpty(Map<String, Object?> m, String key, String path) =>
    m[key] == null ? const [] : stringsAt(m, key, path);

Map<String, Object?> mapOrEmpty(
  Map<String, Object?> m,
  String key,
  String path,
) => m[key] == null ? const {} : mapAt(m, key, path);
