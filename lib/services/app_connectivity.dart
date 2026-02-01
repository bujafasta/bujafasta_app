import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class AppConnectivity {
  AppConnectivity._internal();
  static final AppConnectivity _instance = AppConnectivity._internal();
  factory AppConnectivity() => _instance;

  final Connectivity _connectivity = Connectivity();

  final StreamController<ConnectivityResult> _controller =
      StreamController<ConnectivityResult>.broadcast();

  ConnectivityResult _currentStatus = ConnectivityResult.none;

  /// 🔊 Listen to connectivity changes (GLOBAL)
  Stream<ConnectivityResult> get stream => _controller.stream;

  /// 📌 Get last known status
  ConnectivityResult get current => _currentStatus;

  /// 🚀 Call this ONCE (app start)
  void initialize() {
    _connectivity.onConnectivityChanged.listen((results) {
      // ✅ NEW API RETURNS A LIST
      final ConnectivityResult newStatus =
          results.isNotEmpty ? results.first : ConnectivityResult.none;

      if (newStatus != _currentStatus) {
        _currentStatus = newStatus;
        _controller.add(newStatus);
      }
    });
  }

  bool get hasConnection => _currentStatus != ConnectivityResult.none;

  void dispose() {
    _controller.close();
  }
}
