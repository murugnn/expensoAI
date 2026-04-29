import 'package:flutter/foundation.dart';
import 'package:expenso/models/notification_event.dart';
import 'package:expenso/services/notification_service.dart';

/// Provider-agnostic push interface.
///
/// The shipping default is [LocalOnlyPushService], which forwards events to
/// the existing [NotificationService] for local-notification delivery only.
/// When you wire up FCM (or OneSignal, or APNs-direct), implement
/// [PushService] in a new file and swap the registration in `main.dart`:
///
/// ```dart
/// PushService.instance = FcmPushService()..register();
/// ```
abstract class PushService {
  static PushService instance = LocalOnlyPushService();

  /// Initialize tokens, register foreground/background handlers, etc.
  Future<void> register();

  /// Tear down handlers (e.g. on logout) and forget the device token.
  Future<void> unregister();

  /// Best-effort delivery for a server-emitted [NotificationEvent].
  /// Implementations decide whether to show a tray notification, badge, or
  /// no-op (e.g. if the event arrived while the app is in foreground).
  Future<void> deliver(NotificationEvent event);
}

/// Default implementation: never registers a device token, only mirrors
/// inbox events to the on-device notification tray. Safe to ship now;
/// upgrade later by adding a real [PushService] subclass.
class LocalOnlyPushService implements PushService {
  // Spread fixed IDs so multiple events at once don't collide.
  static const int _baseId = 5000;
  int _next = _baseId;
  int _nextId() => _next++ & 0x7fffffff;

  @override
  Future<void> register() async {
    debugPrint('[PushService] LocalOnly mode active (no remote tokens).');
  }

  @override
  Future<void> unregister() async {}

  @override
  Future<void> deliver(NotificationEvent event) async {
    try {
      await NotificationService.instance.showNow(
        id: _nextId(),
        title: event.title,
        body: event.body ?? '',
        payload: event.type,
      );
    } catch (e) {
      debugPrint('[PushService] local delivery failed: $e');
    }
  }
}
