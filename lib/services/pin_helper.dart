import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class PinHelper {
  static String _generateSalt([int length = 16]) {
    final random = Random.secure();
    final bytes = List<int>.generate(length, (_) => random.nextInt(256));
    return base64Encode(bytes);
  }

  /// Returns "salt:hash" string for storage.
  static String hashPin(String pin) {
    final salt = _generateSalt();
    final hash = sha256.convert(utf8.encode('$salt:$pin')).toString();
    return '$salt:$hash';
  }

  /// Verifies a raw pin against a stored "salt:hash" string.
  static bool verifyPin(String rawPin, String stored) {
    final parts = stored.split(':');
    if (parts.length != 2) {
      // Legacy unhashed pin — direct comparison
      return rawPin == stored;
    }
    final salt = parts[0];
    final storedHash = parts[1];
    final computedHash = sha256.convert(utf8.encode('$salt:$rawPin')).toString();
    return computedHash == storedHash;
  }
}
