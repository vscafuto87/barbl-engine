import '../contract/profile.dart' show emphasisMaxItems, emphasisValues;
import '../kb/kb_format_exception.dart';
import '../kb/knowledge_base.dart';
import '../kb/reader.dart';
import 'photo_types.dart';

/// Gruppo di parametri della KB con le regole di `suggestEmphasis`.
const String photoEmphasisGroup = 'photoEmphasis';

/// Identificativi delle motivazioni (`kb/rationales/`) che `suggestEmphasis`
/// cita: formato del risultato.
const String ruleSuggest = 'PHOTO-EMPHASIS-SUGGEST';
const String ruleNoEvidence = 'PHOTO-EMPHASIS-NO-EVIDENCE';
const String ruleNoData = 'PHOTO-EMPHASIS-NO-DATA';
const String ruleDataDisagrees = 'PHOTO-EMPHASIS-DATA-DISAGREES';
const String ruleNoRoom = 'PHOTO-EMPHASIS-NO-ROOM';
const String ruleMoreVolume = 'PHOTO-EMPHASIS-MORE-VOLUME';

const List<String> _allRuleIds = [
  ruleSuggest,
  ruleNoEvidence,
  ruleNoData,
  ruleDataDisagrees,
  ruleNoRoom,
  ruleMoreVolume,
];

/// Regole di `suggestEmphasis` lette dalla KB (`parameters/photoEmphasis`):
/// nessun valore ha un predefinito nel codice.
class PhotoEmphasisRules {
  const PhotoEmphasisRules({
    required this.minConfidence,
    required this.maxEmphasis,
    required this.regionOrder,
    required this.emphasisOf,
    required this.notEmphasizable,
    required this.minPlannedWeeklySets,
    required this.minDoneOverPlanned,
    required this.maxDoneOverPlanned,
    required this.maxExtraWeeklySets,
  });

  /// Legge e controlla il gruppo; [KbFormatException] con il percorso del
  /// campo se manca o non è valido.
  factory PhotoEmphasisRules.fromKb(KnowledgeBase kb) {
    final group = kb.parameterGroups[photoEmphasisGroup];
    if (group == null) {
      throw KbFormatException(
        'parameters.$photoEmphasisGroup: gruppo mancante',
      );
    }
    const path = 'parameters.$photoEmphasisGroup.values';
    final v = group.values;
    final confidence = PhotoConfidence.parse(
      stringAt(v, 'minConfidence', path),
    );
    if (confidence == null || confidence == PhotoConfidence.insufficient) {
      throw KbFormatException(
        '$path.minConfidence: deve essere low, medium o high',
      );
    }
    final maxEmphasis = intAt(v, 'maxEmphasis', path);
    if (maxEmphasis < 1 || maxEmphasis > emphasisMaxItems) {
      throw KbFormatException(
        '$path.maxEmphasis: deve essere tra 1 e $emphasisMaxItems',
      );
    }
    final order = <PhotoRegion>[];
    final emphasisOf = <PhotoRegion, String>{};
    final entries = listAt(v, 'regions', path);
    for (var i = 0; i < entries.length; i++) {
      final p = '$path.regions[$i]';
      final m = asMap(entries[i], p);
      final region = PhotoRegion.parse(stringAt(m, 'region', p));
      if (region == null) {
        throw KbFormatException('$p.region: regione sconosciuta');
      }
      final emphasis = stringAt(m, 'emphasis', p);
      if (!emphasisValues.contains(emphasis)) {
        throw KbFormatException(
          '$p.emphasis: $emphasis non è un valore di emphasis del profilo',
        );
      }
      if (emphasisOf.containsKey(region)) {
        throw KbFormatException('$p.region: regione ripetuta');
      }
      order.add(region);
      emphasisOf[region] = emphasis;
    }
    final notEmphasizable = <PhotoRegion>{};
    for (final s in stringsAt(v, 'notEmphasizable', path)) {
      final region = PhotoRegion.parse(s);
      if (region == null || emphasisOf.containsKey(region)) {
        throw KbFormatException(
          '$path.notEmphasizable: $s sconosciuta o anche in regions',
        );
      }
      notEmphasizable.add(region);
    }
    final minDone = doubleAt(v, 'minDoneOverPlanned', path);
    final maxDone = doubleAt(v, 'maxDoneOverPlanned', path);
    if (minDone < 0 || maxDone < minDone) {
      throw KbFormatException(
        '$path.minDoneOverPlanned: deve essere tra 0 e maxDoneOverPlanned',
      );
    }
    final minPlanned = doubleAt(v, 'minPlannedWeeklySets', path);
    final maxExtra = doubleAt(v, 'maxExtraWeeklySets', path);
    if (minPlanned < 0 || maxExtra < 0) {
      throw KbFormatException(
        '$path: minPlannedWeeklySets e maxExtraWeeklySets non possono essere negativi',
      );
    }
    for (final id in _allRuleIds) {
      if (!kb.rationales.any((r) => r.ruleId == id)) {
        throw KbFormatException(
          'rationales.$id: manca ma esiste $photoEmphasisGroup',
        );
      }
    }
    return PhotoEmphasisRules(
      minConfidence: confidence,
      maxEmphasis: maxEmphasis,
      regionOrder: order,
      emphasisOf: emphasisOf,
      notEmphasizable: notEmphasizable,
      minPlannedWeeklySets: minPlanned,
      minDoneOverPlanned: minDone,
      maxDoneOverPlanned: maxDone,
      maxExtraWeeklySets: maxExtra,
    );
  }

  /// Confidenza minima per tenere conto di un'osservazione.
  final PhotoConfidence minConfidence;

  /// Distretti proposti al massimo.
  final int maxEmphasis;

  /// Regioni con un valore di `emphasis`, nell'ordine di spareggio.
  final List<PhotoRegion> regionOrder;

  /// Valore di `emphasis` di ogni regione enfatizzabile.
  final Map<PhotoRegion, String> emphasisOf;

  /// Regioni che il profilo non sa enfatizzare.
  final Set<PhotoRegion> notEmphasizable;

  final double minPlannedWeeklySets;
  final double minDoneOverPlanned;
  final double maxDoneOverPlanned;
  final double maxExtraWeeklySets;
}
