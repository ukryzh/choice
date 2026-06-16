import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinService {
  PinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _pinKey = 'user_pin_code';
  static const _pinSetKey = 'pin_code_set';

  Future<void> setPin(String pin) async {
    if (pin.length != 4 || !pin.contains(RegExp(r'^\d+$'))) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _pinSetKey, value: 'true');
  }

  Future<bool> verifyPin(String pin) async {
    final storedPin = await _storage.read(key: _pinKey);
    return storedPin == pin;
  }

  Future<bool> isPinSet() async {
    final pinSet = await _storage.read(key: _pinSetKey);
    return pinSet == 'true';
  }

  Future<void> clearPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinSetKey);
  }
}












