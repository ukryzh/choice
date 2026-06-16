import 'package:flutter/material.dart';

import '../models/symptom.dart';

class SymptomChip extends StatelessWidget {
  const SymptomChip({
    super.key,
    required this.symptom,
    required this.selected,
    required this.onTap,
  });

  final SymptomType symptom;
  final SymptomIntensity selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = symptom.label;
    return ChoiceChip(
      label: Text(label),
      selected: selected != SymptomIntensity.none,
      onSelected: (_) => onTap(),
    );
  }
}


