import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// Single source of truth for online/offline status.
/// Emits `true` when internet is reachable, `false` otherwise.
class ConnectivityService {
  ConnectivityService._();
  static final ConnectivityService I = ConnectivityService._();

  final _controller = StreamController<bool>.broadcast();
  late final StreamSubscription _sub;
  bool _last = true;

  /// Start listening (call once at app boot).
  void start() {
    // Listen to connectivity changes and verify real internet.
    _sub = Connectivity().onConnectivityChanged.listen((_) async {
      final online = await InternetConnection().hasInternetAccess;
      if (online != _last) {
        _last = online;
        _controller.add(online);
      }
    });

    // Emit initial state
    InternetConnection().hasInternetAccess.then((v) {
      _last = v;
      _controller.add(v);
    });
  }

  void dispose() {
    _sub.cancel();
    _controller.close();
  }

  /// Stream of connectivity (true = online, false = offline).
  Stream<bool> get online$ => _controller.stream;

  /// One-shot check.
  Future<bool> get isOnline async => InternetConnection().hasInternetAccess;
}
