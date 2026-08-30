class AdminSecurityService {
  // Default Admin PIN / Password
  static String _adminPin = '1234';

  /// Verifies if the provided PIN/password matches the admin PIN.
  static bool verifyPin(String enteredPin) {
    return enteredPin.trim() == _adminPin.trim();
  }

  /// Updates the admin PIN if the current PIN is verified correctly.
  static bool changePin({required String currentPin, required String newPin}) {
    if (verifyPin(currentPin) && newPin.trim().isNotEmpty) {
      _adminPin = newPin.trim();
      return true;
    }
    return false;
  }

  /// Getter for current PIN (for administrative reference/debugging)
  static String get currentPin => _adminPin;
}
