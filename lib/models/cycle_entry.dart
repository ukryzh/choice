import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

import 'symptom.dart';

class CycleEntry extends Equatable {
  CycleEntry({
    String? id,
    required this.cycleStart,
    required this.cycleEnd,
    this.symptoms = const [],
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  factory CycleEntry.fromJson(Map<String, dynamic> json) {
    return CycleEntry(
      id: json['id'] as String?,
      cycleStart: DateTime.parse(json['cycleStart'] as String),
      cycleEnd: DateTime.parse(json['cycleEnd'] as String),
      symptoms: (json['symptoms'] as List<dynamic>? ?? [])
          .map((item) => SymptomLog.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  final String id;
  final DateTime cycleStart;
  final DateTime cycleEnd;
  final List<SymptomLog> symptoms;
  final DateTime createdAt;

  int get duration => cycleEnd.difference(cycleStart).inDays + 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cycleStart': cycleStart.toIso8601String(),
        'cycleEnd': cycleEnd.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'symptoms': symptoms.map((s) => s.toJson()).toList(),
      };

  String encode() => jsonEncode(toJson());

  @override
  List<Object?> get props => [id, cycleStart, cycleEnd, symptoms, createdAt];
}


