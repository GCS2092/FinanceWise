import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> hasBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } catch (e) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return false;

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour continuer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<String?> getAvailableBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) return null;

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      return availableBiometrics.join(', ');
    } catch (e) {
      return null;
    }
  }
}
