import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasscodeService {
  final _storage = const FlutterSecureStorage();

  String _key(String userId) => 'passcode_$userId';

  Future<bool> hasPasscode(String userId) async {
    final value = await _storage.read(key: _key(userId));
    return value != null && value.isNotEmpty;
  }

  Future<void> setPasscode(String userId, String passcode) async {
    await _storage.write(key: _key(userId), value: passcode);
  }

  Future<bool> verifyPasscode(String userId, String passcode) async {
    final stored = await _storage.read(key: _key(userId));
    return stored == passcode;
  }

  Future<void> removePasscode(String userId) async {
    await _storage.delete(key: _key(userId));
  }
}
