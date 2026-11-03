import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Service managing real-time online/offline presence for active users.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  final Map<String, bool> _onlineStatusCache = {};
  String? _activeUserId;
  String? _activeDoctorId;
  bool _isInitialized = false;

  bool isUserOnline(String userId) => _onlineStatusCache[userId] ?? false;

  void updateUserPresenceLocally(String userId, bool online) {
    _onlineStatusCache[userId] = online;
  }

  void initialize(String userId, {String? doctorId}) {
    if (userId.isEmpty) return;
    _activeUserId = userId;
    if (doctorId != null && doctorId.isNotEmpty) {
      _activeDoctorId = doctorId;
      _onlineStatusCache[doctorId] = true;
    }
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
      if (_activeDoctorId != null) {
        _onlineStatusCache[_activeDoctorId!] = false;
      }
      _activeUserId = null;
      _activeDoctorId = null;
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
    final uid = _activeUserId;
    if (uid == null || uid.isEmpty) return;
    _onlineStatusCache[uid] = online;
    if (_activeDoctorId != null) {
      _onlineStatusCache[_activeDoctorId!] = online;
    }

    final currentAuth = FirebaseAuth.instance.currentUser;
    if (currentAuth == null || currentAuth.uid != uid) {
      return;
    }

    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'isOnline': online,
        'lastSeen': nowIso,
      }, SetOptions(merge: true));

      if (_activeDoctorId != null && _activeDoctorId!.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('doctors')
            .doc(_activeDoctorId)
            .set({
          'isOnline': online,
          'lastSeen': nowIso,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('PresenceService notice: $e');
    }
  }
}
