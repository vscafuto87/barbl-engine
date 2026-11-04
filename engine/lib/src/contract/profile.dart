/// Lettura del profilo del contratto (`kb/contract/profile.schema.json`).
library;

// ---------------------------------------------------------------------------
// Costanti di formato del contratto, copiate dallo schema del profilo.
// Non sono numeri di dominio: si aggiornano solo insieme allo schema.
// ---------------------------------------------------------------------------
const Set<String> _profileSchemaVersions = {'1.0', '1.1'};
const Set<String> _equipmentValues = {
  'barbell',
  'rack',
  'bench',
  'dumbbells',
  'machines',
  'cables',
  'smith_machine',
};
const Set<String> _goalValues = {'muscle_gain', 'strength', 'both'};
const Set<String> _gymTypeValues = {'full', 'home', 'dumbbells'};
const Set<int> _daysPerWeekValues = {3, 4, 5};
const Set<int> _sessionDurationValues = {45, 60, 75, 90};
const Set<String> _experienceValues = {
  'under_6_months',
  '6_months_2_years',
  'over_2_years',
};
const double _defaultBarKg = 20;
const List<double> _defaultPlatesKg = <double>[25, 20, 15, 10, 5, 2.5, 1.25];

const Set<String> _topKeys = {
  'schemaVersion',
  'goal',
  'gym',
  'daysPerWeek',
  'sessionDurationMin',
  'experience',
  'knownLoads',
};
const Set<String> _gymKeys = {'type', 'equipment', 'barKg', 'platesKg'};
const Set<String> _knownLoadKeys = {'exerciseId', 'kg', 'reps'};

/// Profilo dell'utente, già validato.
class Profile {
  const Profile({
    required this.goal,
    required this.gymType,
    required this.equipment,
    required this.barKg,
    required this.platesKg,
    required this.daysPerWeek,
    required this.sessionDurationMin,
    required this.experience,
    required this.knownLoads,
  });

  final String goal;
  final String gymType;
  final Set<String> equipment;
  final double barKg;
  final List<double> platesKg;
  final int daysPerWeek;
  final int sessionDurationMin;
  final String experience;

  /// `exerciseId` -> kg; `null` = «Non lo so».
  final Map<String, double?> knownLoads;
}

sealed class ProfileRead {
  const ProfileRead();
}

final class ProfileOk extends ProfileRead {
  const ProfileOk(this.profile);
  final Profile profile;
}

final class ProfileErrors extends ProfileRead {
  const ProfileErrors(this.errors);

  /// Ogni voce: percorso e motivo.
  final List<String> errors;
}

String _join(String path, String key) => path.isEmpty ? key : '$path.$key';

String _describe(Object? value) => value == null ? 'null' : '$value';

void _checkKeys(Map<Object?, Object?> map, Set<String> allowed, String path,
    List<String> errors) {
  for (final key in map.keys) {
    if (key is! String || !allowed.contains(key)) {
      errors.add(
          '${_join(path, '$key')}: campo sconosciuto');
    }
  }
}

bool _isFiniteNum(Object? v) => v is num && v.isFinite;

/// Un intero (anche scritto come 4.0), altrimenti null.
int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is double && v.isFinite && v == v.truncateToDouble()) {
    return v.toInt();
  }
  return null;
}

/// Legge il profilo raccogliendo tutti gli errori. Non lancia mai.
ProfileRead readProfile(Map<String, Object?> json) {
  final errors = <String>[];
  _checkKeys(json, _topKeys, '', errors);

  for (final key in _topKeys) {
    if (!json.containsKey(key)) {
      errors.add('$key: campo obbligatorio mancante');
    }
  }

  if (json.containsKey('schemaVersion') &&
      !_profileSchemaVersions.contains(json['schemaVersion'])) {
    errors.add('schemaVersion: deve essere "1.0" o "1.1", '
        'trovato ${_describe(json['schemaVersion'])}');
  }

  String? goal;
  if (json.containsKey('goal')) {
    final v = json['goal'];
    if (v is String && _goalValues.contains(v)) {
      goal = v;
    } else {
      errors.add('goal: valore non ammesso (${_describe(v)})');
    }
  }

  String? gymType;
  final equipment = <String>{};
  double barKg = _defaultBarKg;
  List<double> platesKg = _defaultPlatesKg;
  if (json.containsKey('gym')) {
    final gym = json['gym'];
    if (gym is! Map) {
      errors.add('gym: deve essere un oggetto');
    } else {
      _checkKeys(gym, _gymKeys, 'gym', errors);
      if (!gym.containsKey('type')) {
        errors.add('gym.type: campo obbligatorio mancante');
      } else {
        final v = gym['type'];
        if (v is String && _gymTypeValues.contains(v)) {
          gymType = v;
        } else {
          errors.add('gym.type: valore non ammesso (${_describe(v)})');
        }
      }
      if (!gym.containsKey('equipment')) {
        errors.add('gym.equipment: campo obbligatorio mancante');
      } else {
        final v = gym['equipment'];
        if (v is! List) {
          errors.add('gym.equipment: deve essere una lista');
        } else {
          for (var i = 0; i < v.length; i++) {
            final item = v[i];
            if (item is String && _equipmentValues.contains(item)) {
              equipment.add(item);
            } else if (item is String) {
              errors.add(
                  'gym.equipment[$i]: valore non ammesso (${_describe(item)})');
            } else {
              errors.add('gym.equipment[$i]: deve essere una stringa');
            }
          }
        }
      }
      if (gym.containsKey('barKg')) {
        final v = gym['barKg'];
        if (_isFiniteNum(v) && (v as num) > 0) {
          barKg = v.toDouble();
        } else {
          errors.add('gym.barKg: deve essere un numero positivo');
        }
      }
      if (gym.containsKey('platesKg')) {
        final v = gym['platesKg'];
        if (v is! List) {
          errors.add('gym.platesKg: deve essere una lista di numeri');
        } else {
          final plates = <double>[];
          for (var i = 0; i < v.length; i++) {
            final item = v[i];
            if (_isFiniteNum(item) && (item as num) > 0) {
              plates.add(item.toDouble());
            } else {
              errors.add('gym.platesKg[$i]: deve essere un numero positivo');
            }
          }
          platesKg = plates;
        }
      }
    }
  }

  int? daysPerWeek;
  if (json.containsKey('daysPerWeek')) {
    final v = _asInt(json['daysPerWeek']);
    if (v != null && _daysPerWeekValues.contains(v)) {
      daysPerWeek = v;
    } else {
      errors.add(
          'daysPerWeek: valore non ammesso (${_describe(json['daysPerWeek'])})');
    }
  }

  int? sessionDurationMin;
  if (json.containsKey('sessionDurationMin')) {
    final v = _asInt(json['sessionDurationMin']);
    if (v != null && _sessionDurationValues.contains(v)) {
      sessionDurationMin = v;
    } else {
      errors.add('sessionDurationMin: valore non ammesso '
          '(${_describe(json['sessionDurationMin'])})');
    }
  }

  String? experience;
  if (json.containsKey('experience')) {
    final v = json['experience'];
    if (v is String && _experienceValues.contains(v)) {
      experience = v;
    } else {
      errors.add('experience: valore non ammesso (${_describe(v)})');
    }
  }

  final knownLoads = <String, double?>{};
  if (json.containsKey('knownLoads')) {
    final v = json['knownLoads'];
    if (v is! List) {
      errors.add('knownLoads: deve essere una lista');
    } else {
      for (var i = 0; i < v.length; i++) {
        final path = 'knownLoads[$i]';
        final item = v[i];
        if (item is! Map) {
          errors.add('$path: deve essere un oggetto');
          continue;
        }
        _checkKeys(item, _knownLoadKeys, path, errors);
        String? id;
        if (!item.containsKey('exerciseId')) {
          errors.add('$path.exerciseId: campo obbligatorio mancante');
        } else if (item['exerciseId'] is! String) {
          errors.add('$path.exerciseId: deve essere una stringa');
        } else {
          id = item['exerciseId'] as String;
        }
        double? kg;
        var kgOk = true;
        if (item.containsKey('kg') && item['kg'] != null) {
          final k = item['kg'];
          if (_isFiniteNum(k) && (k as num) > 0) {
            kg = k.toDouble();
          } else {
            kgOk = false;
            errors.add('$path.kg: deve essere un numero positivo o null');
          }
        }
        if (item.containsKey('reps') && item['reps'] != null) {
          if (_asInt(item['reps']) == null) {
            errors.add('$path.reps: deve essere un intero o null');
          }
        }
        if (id != null) {
          if (knownLoads.containsKey(id)) {
            errors.add('$path.exerciseId: duplicato ($id)');
          } else if (kgOk) {
            knownLoads[id] = kg;
          }
        }
      }
    }
  }

  if (errors.isNotEmpty) return ProfileErrors(List.unmodifiable(errors));

  return ProfileOk(Profile(
    goal: goal!,
    gymType: gymType!,
    equipment: Set.unmodifiable(equipment),
    barKg: barKg,
    platesKg: List.unmodifiable(platesKg),
    daysPerWeek: daysPerWeek!,
    sessionDurationMin: sessionDurationMin!,
    experience: experience!,
    knownLoads: Map.unmodifiable(knownLoads),
  ));
}
