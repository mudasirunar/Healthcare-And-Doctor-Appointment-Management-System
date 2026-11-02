import 'package:flutter/widgets.dart';

/// Service managing real-time online/offline presence for active users.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final Map<String, bool> _onlineStatusCache = {};
  String? _activeUserId;
  bool _isInitialized = false;

  bool isUserOnline(String userId) => _onlineStatusCache[userId] ?? false;

  void updateUserPresenceLocally(String userId, bool online) {
    _onlineStatusCache[userId] = online;
  }

  void initialize(String userId) {
    if (userId.isEmpty || (_activeUserId == userId && _isInitialized)) return;
    _activeUserId = userId;
    _onlineStatusCache[userId] = true;

    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
    }

    setOnline(true);
  }

  void dispose() {
    if (_isInitialized) {
      setOnline(false);
      WidgetsBinding.instance.removeObserver(this);
      _isInitialized = false;
      if (_activeUserId != null) {
        _onlineStatusCache[_activeUserId!] = false;
      }
      _activeUserId = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      setOnline(false);
    }
  }

  Future<void> setOnline(bool online) async {
    // Permanently disabled: zero Firestore writes to prevent presence loops
    return;
  }
}

