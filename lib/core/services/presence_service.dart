import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/users/repository/user_repository.dart';

/// Watches the app's lifecycle AND sends a periodic "heartbeat" while
/// the app is active, updating Firestore's isOnline/lastSeen fields.
///
/// Why a heartbeat, not just lifecycle events: if the app is killed
/// abruptly (swiped away, OS kills it in the background, battery
/// optimization interrupts it), Flutter's didChangeAppLifecycleState
/// may never fire "paused" in time to write isOnline: false — leaving
/// the user stuck showing "online" forever. The heartbeat means other
/// users can treat a stale lastSeen (older than ~45 seconds) as
/// effectively offline, regardless of whether a clean shutdown event
/// ever happened.
class PresenceService with WidgetsBindingObserver {
  final UserRepository _userRepository;
  final String uid;
  Timer? _heartbeatTimer;

  PresenceService({required this.uid, UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _setOnline(true); // refreshes lastSeen every 20s while app is active
    });
  }

  void stop() {
    _heartbeatTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _setOnline(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        _setOnline(true);
      });
      _setOnline(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      // Stop the heartbeat immediately and try to write offline right
      // away — this covers the clean-shutdown case. The heartbeat
      // staleness check (in UserRepository/UI) covers the unclean case.
      _heartbeatTimer?.cancel();
      _setOnline(false);
    }
  }

  void _setOnline(bool isOnline) {
    _userRepository.setOnlineStatus(uid: uid, isOnline: isOnline);
  }
}

/// App-wide singleton so PresenceService survives navigation between
/// screens without needing to be threaded through the widget tree.
class PresenceManager {
  PresenceManager._();
  static final PresenceManager instance = PresenceManager._();

  PresenceService? _service;

  void start(String uid) {
    _service?.stop();
    _service = PresenceService(uid: uid)..start();
  }

  void stop() {
    _service?.stop();
    _service = null;
  }
}