import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onConnectivityChanged async* {
    await for (var results in _connectivity.onConnectivityChanged) {
      // results est une List<ConnectivityResult>
      yield results.isNotEmpty && !results.contains(ConnectivityResult.none);
    }
  }

  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    // results est une List<ConnectivityResult>
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }
}
