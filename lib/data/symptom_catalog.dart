import '../models/symptom.dart';

class SymptomCatalog {
  static const entries = SymptomType.values;

  static SymptomIntensity defaultIntensity(SymptomType type) {
    switch (type) {
      case SymptomType.cramps:
      case SymptomType.headache:
        return SymptomIntensity.moderate;
      default:
        return SymptomIntensity.mild;
    }
  }
}


