import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';


class NetworkHelper {
  static final NetworkHelper _instance = NetworkHelper._internal();
  factory NetworkHelper() => _instance;
  NetworkHelper._internal();

  final _connectivityStreamController = StreamController<bool>.broadcast();
  Timer? _periodicTimer;
  bool _isCheckingConnection = false;
  bool _lastConnectionState = false;

  Stream<bool> get connectionStream => _connectivityStreamController.stream;

  void initNetworkMonitoring({Duration checkInterval = const Duration(seconds: 2)}) {
    _periodicTimer?.cancel();
    
    // Première vérification immédiate
    _checkConnection();
    
    // Vérification périodique
    _periodicTimer = Timer.periodic(checkInterval, (timer) {
      _checkConnection();
    });

    // Surveillance des changements de connectivité avec debounce
    var lastConnectionChange = DateTime.now();
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
      // Éviter les changements trop rapprochés (debounce)
      if (DateTime.now().difference(lastConnectionChange) < const Duration(seconds: 1)) {
        return;
      }
      lastConnectionChange = DateTime.now();

      if (result == ConnectivityResult.none) {
        _lastConnectionState = false;
        if (!_connectivityStreamController.isClosed) {
          _connectivityStreamController.add(false);
        }
      } else {
        // Attendre que la connexion se stabilise
        await Future.delayed(const Duration(seconds: 1));
        _checkConnection();
      }
    });
  }

  Future<bool> isConnected() async {
    if (_isCheckingConnection) return _lastConnectionState;
    
    try {
      _isCheckingConnection = true;
      final connectivityResult = await Connectivity().checkConnectivity();
      
      if (connectivityResult == ConnectivityResult.none) {
        _lastConnectionState = false;
        return false;
      }

      final result = await Future.wait([
        InternetAddress.lookup('google.com'),
      ]).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw const SocketException('Timeout'),
      );

      _lastConnectionState = result.any((lookup) => lookup.isNotEmpty);
      return _lastConnectionState;
    } catch (_) {
      _lastConnectionState = false;
      return false;
    } finally {
      _isCheckingConnection = false;
    }
  }

  Future<void> _checkConnection() async {
    if (_connectivityStreamController.isClosed || _isCheckingConnection) return;

    try {
      final isConnected = await this.isConnected();
      
      if (!_connectivityStreamController.isClosed) {
        _connectivityStreamController.add(isConnected);
      }
    } catch (_) {
      if (!_connectivityStreamController.isClosed) {
        _connectivityStreamController.add(false);
      }
    }
  }

  void dispose() {
    _periodicTimer?.cancel();
    _connectivityStreamController.close();
  }
}
