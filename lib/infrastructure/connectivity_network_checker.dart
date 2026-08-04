import 'package:connectivity_plus/connectivity_plus.dart';
import '../domain/i_check_network_connection.dart';

class ConnectivityNetworkChecker implements ICheckNetworkConnection {
  final Connectivity _connectivity;

  ConnectivityNetworkChecker(this._connectivity);

  @override
  Future<bool> get isConnected async {
    final results = await _connectivity.checkConnectivity();
    if (results.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }
}