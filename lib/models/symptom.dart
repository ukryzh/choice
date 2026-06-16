import 'dart:convert';

import 'package:equatable/equatable.dart';

enum SymptomType {
  cramps,
  headache,
  moodSwing,
  fatigue,
  cravings,
  acne,
  insomnia,
}

enum SymptomIntensity { none, mild, moderate, severe }

extension SymptomTypeMeta on SymptomType {
  String get label {
    switch (this) {
      case SymptomType.cramps:
        return 'Cramps';
      case SymptomType.headache:
        return 'Headache';
      case SymptomType.moodSwing:
        return 'Mood swings';
      case SymptomType.fatigue:
        return 'Fatigue';
      case SymptomType.cravings:
        return 'Cravings';
      case SymptomType.acne:
        return 'Skin changes';
      case SymptomType.insomnia:
        return 'Insomnia';
    }
  }
}

class SymptomLog extends Equatable {
  const SymptomLog({
    required this.type,
    this.intensity = SymptomIntensity.mild,
    this.notes,
  });

  factory SymptomLog.fromJson(Map<String, dynamic> json) {
    return SymptomLog(
      type: SymptomType.values
          .firstWhere((t) => t.name == json['type'], orElse: () => SymptomType.cramps),
      intensity: SymptomIntensity.values
          .firstWhere((i) => i.name == json['intensity'], orElse: () => SymptomIntensity.mild),
      notes: json['notes'] as String?,
    );
  }

  final SymptomType type;
  final SymptomIntensity intensity;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'intensity': intensity.name,
        'notes': notes,
      };

  @override
  List<Object?> get props => [type, intensity, notes];

  @override
  String toString() => jsonEncode(toJson());
}


