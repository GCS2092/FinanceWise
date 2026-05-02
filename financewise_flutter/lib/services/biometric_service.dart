import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'logger_service.dart';

class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> hasBiometrics() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        if (kDebugMode) {
          LoggerService().warning('Biométrie non disponible sur cet appareil');
        }
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        if (kDebugMode) {
          LoggerService().warning('Aucune biométrie configurée (empreinte/FaceID non enregistrée)');
        }
        return false;
      }

      if (kDebugMode) {
        LoggerService().debug('Biométrie disponible: ${availableBiometrics.join(', ')}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        LoggerService().error('Erreur vérification biométrie', e);
      }
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      if (!isAvailable) {
        if (kDebugMode) {
          LoggerService().warning('Authentification biométrique non disponible');
        }
        return false;
      }

      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        if (kDebugMode) {
          LoggerService().warning('Aucune biométrie configurée sur l\'appareil');
        }
        return false;
      }

      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Veuillez vous authentifier pour continuer',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );

      if (kDebugMode) {
        LoggerService().info('Authentification biométrique: ${didAuthenticate ? 'succès' : 'échec'}');
      }
      return didAuthenticate;
    } catch (e) {
      if (kDebugMode) {
        LoggerService().error('Erreur authentification biométrique', e);
      }
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
      if (kDebugMode) {
        LoggerService().error('Erreur récupération biométries', e);
      }
      return null;
    }
  }
}
