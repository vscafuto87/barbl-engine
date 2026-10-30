import 'kb_format_exception.dart';
import 'models.dart';
import 'reader.dart';

/// Knowledge base letta dal pacchetto JSON (stessa forma che scrive `bundle`).
class KnowledgeBase {
  KnowledgeBase._({
    required this.rulesVersion,
    required this.kbCommit,
    required this.primaryWeight,
    required this.secondaryWeight,
    required this.exercises,
    required this.templates,
    required this.prescriptions,
    required this.parameterGroups,
    required this.rationales,
    required this.principles,
    required this.sources,
  });

  /// Formato del pacchetto che questa versione del motore sa leggere.
  static const int supportedBundleFormat = 1;

  factory KnowledgeBase.fromJson(Map<String, Object?> json) {
    const root = r'$';
    final format = intAt(json, 'bundleFormat', root);
    if (format != supportedBundleFormat) {
      throw KbFormatException(
        '$root.bundleFormat: formato $format non supportato '
        '(atteso $supportedBundleFormat)',
      );
    }
    final weights = mapAt(json, 'setWeights', root);

    Map<String, T> collection<T>(
      String key,
      T Function(Map<String, Object?>, String) read,
    ) {
      final m = mapAt(json, key, root);
      return {
        for (final e in m.entries)
          e.key: read(asMap(e.value, '$key.${e.key}'), '$key.${e.key}'),
      };
    }

    List<T> sortedList<T>(
      String key,
      T Function(Map<String, Object?>, String) read,
    ) {
      final m = mapAt(json, key, root);
      final ids = m.keys.toList()..sort();
      return [
        for (final id in ids) read(asMap(m[id], '$key.$id'), '$key.$id'),
      ];
    }

    final rationaleMap = collection('rationales', KbRationale.fromJson);
    final ruleIds = rationaleMap.keys.toList()..sort();

    return KnowledgeBase._(
      rulesVersion: stringAt(json, 'rulesVersion', root),
      kbCommit: stringOrNull(json, 'kbCommit', root),
      primaryWeight: doubleAt(weights, 'primary', 'setWeights'),
      secondaryWeight: doubleAt(weights, 'secondary', 'setWeights'),
      exercises: collection('exercises', KbExercise.fromJson),
      templates: sortedList('templates', KbTemplate.fromJson),
      prescriptions: sortedList('prescriptions', KbPrescription.fromJson),
      parameterGroups: collection('parameters', KbParameterGroup.fromJson),
      rationales: [for (final id in ruleIds) rationaleMap[id]!],
      principles: collection('principles', KbPrinciple.fromJson),
      sources: collection('sources', KbSource.fromJson),
    );
  }

  final String rulesVersion;
  final String? kbCommit;
  final double primaryWeight;
  final double secondaryWeight;
  final Map<String, KbExercise> exercises;
  final List<KbTemplate> templates;
  final List<KbPrescription> prescriptions;
  final Map<String, KbParameterGroup> parameterGroups;
  final List<KbRationale> rationales;
  final Map<String, KbPrinciple> principles;
  final Map<String, KbSource> sources;
}
