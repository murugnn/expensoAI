import 'package:flutter/services.dart';

class LaunchIntentService {
  static const MethodChannel _channel = MethodChannel('expenso/launch');

  static Future<String?> getLaunchRoute() async {
    try {
      return await _channel.invokeMethod<String>('getLaunchRoute');
    } catch (_) {
      return null;
    }
  }
}
