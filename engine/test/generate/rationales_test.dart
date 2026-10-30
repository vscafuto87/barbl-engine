import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/rationales.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';

Map<String, Object?> _source(String id, int tier, {String use = 'public',
    String type = 'meta_analysis', String? url, String reference = 'Rif'}) => {
  'id': id,
  'type': type,
  'tier': tier,
  'title': 'Titolo $id',
  'reference': reference,
  'use': use,
  if (url != null) 'url': url,
};

Map<String, Object?> _rationale(String ruleId, {
  List<String>? principles,
  String? sourcesFrom,
  Map<String, Object?>? values,
}) => {
  'ruleId': ruleId,
  'key': 'k.$ruleId',
  'level': 'set',
  'text': {'it': 'it $ruleId', 'en': 'en $ruleId'},
  if (values != null) 'exampleValues': values,
  if (principles != null) 'principles': principles,
  if (sourcesFrom != null) 'sourcesFrom': sourcesFrom,
};

KnowledgeBase _kb() {
  final b = minimalBundle();
  b['sources'] = {
    's1': _source('s1', 1, type: 'position_stand', url: 'https://x.org'),
    's2': _source('s2', 3),
    's3': _source('s3', 5, reference: ''),
    's4': _source('s4', 4),
    'sint': _source('sint', 4, use: 'internal', type: 'book'),
    'sdes': _source('sdes', 5, type: 'design'),
    's0': _source('s0', 2),
  };
  b['principles'] = {
    'P-1': {
      'id': 'P-1',
      'sources': [
        {'id': 's3'},
        {'id': 's2'},
        {'id': 's1'},
        {'id': 'sint'},
      ],
    },
    'P-2': {
      'id': 'P-2',
      'sources': [
        {'id': 's1'},
        {'id': 's4'},
        {'id': 's0'},
      ],
    },
    'P-3': {
      'id': 'P-3',
      'sources': [
        {'id': 'sint'},
        {'id': 'sdes'},
      ],
    },
  };
  final params = b['parameters']! as Map<String, Object?>;
  (params['progression']! as Map<String, Object?>)['principles'] = ['P-2'];
  b['rationales'] = {
    'Z-LAST': _rationale('Z-LAST', principles: ['P-1']),
    'A-FIRST': _rationale(
      'A-FIRST',
      sourcesFrom: 'parameters/progression',
      values: {'n': 3},
    ),
    'M-NONE': _rationale('M-NONE', principles: ['P-3']),
    'N-EMPTY': _rationale('N-EMPTY'),
  };
  return KnowledgeBase.fromJson(b);
}

Map<String, Object?> _byRule(List<Map<String, Object?>> list, String id) =>
    list.firstWhere((r) => r['ruleId'] == id);

void main() {
  final list = buildRationales(_kb());

  test('tutte le motivazioni, ordinate per ruleId', () {
    expect(list.map((r) => r['ruleId']).toList(),
        ['A-FIRST', 'M-NONE', 'N-EMPTY', 'Z-LAST']);
  });

  test('chiavi, values e testi', () {
    final r = _byRule(list, 'A-FIRST');
    expect(r.keys.toList(),
        ['ruleId', 'level', 'key', 'values', 'text', 'sources']);
    expect(r['level'], 'set');
    expect(r['key'], 'k.A-FIRST');
    expect(r['values'], {'n': 3});
    expect(r['text'], {'it': 'it A-FIRST', 'en': 'en A-FIRST'});
    expect(_byRule(list, 'Z-LAST')['values'], <String, Object?>{});
  });

  test('fonti dai principi, per tier poi id, con evidenza', () {
    final sources = _byRule(list, 'Z-LAST')['sources']! as List<Object?>;
    expect(sources, [
      {
        'title': 'Titolo s1',
        'reference': 'Rif',
        'url': 'https://x.org',
        'evidence': 'high',
      },
      {'title': 'Titolo s2', 'reference': 'Rif', 'evidence': 'medium'},
      {'title': 'Titolo s3', 'reference': '—', 'evidence': 'low'},
    ]);
    expect((sources[1]! as Map).containsKey('url'), isFalse);
  });

  test('sourcesFrom segue i principi del gruppo; tier 1-2 high, 4 medium', () {
    final sources = _byRule(list, 'A-FIRST')['sources']! as List<Object?>;
    expect(
      [for (final s in sources) (s! as Map)['title']],
      ['Titolo s1', 'Titolo s0', 'Titolo s4'],
    );
    expect(
      [for (final s in sources) (s! as Map)['evidence']],
      ['high', 'high', 'medium'],
    );
  });

  test('fonti interne e di design escluse; nessuna fonte -> lista vuota', () {
    expect(_byRule(list, 'M-NONE')['sources'], isEmpty);
    expect(_byRule(list, 'N-EMPTY')['sources'], isEmpty);
  });
}
