import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:expenso/services/niva_voice_service.dart';
import 'package:expenso/services/tool_executor.dart';
import 'package:expenso/models/expense.dart';
import 'package:vapi/vapi.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/features/goals/models/goal_model.dart';
import 'package:expenso/models/contact.dart';

enum NivaStatus { idle, connecting, active }

class NivaTranscript {
  final String role;
  final String content;
  final DateTime timestamp;

  NivaTranscript({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class NivaVoiceProvider extends ChangeNotifier {
  final NivaVoiceService _service = NivaVoiceService();

  NivaStatus _status = NivaStatus.idle;
  bool _isSpeaking = false;
  bool _isMuted = false;
  final List<NivaTranscript> _messages = [];
  NivaTranscript? _liveTranscript;
  StreamSubscription<VapiEvent>? _eventSub;

  BuildContext? _navContext;

  NivaStatus get status => _status;
  bool get isSpeaking => _isSpeaking;
  bool get isMuted => _isMuted;
  List<NivaTranscript> get messages => List.unmodifiable(_messages);
  NivaTranscript? get liveTranscript => _liveTranscript;
  bool get isActive => _status == NivaStatus.active;
  bool get isConnecting => _status == NivaStatus.connecting;

  NivaVoiceProvider() {
    _service.init();
  }

  void setNavContext(BuildContext context) {
    _navContext = context;
  }

  void _subscribeToCallEvents(VapiCall call) {
    _eventSub?.cancel();
    _eventSub = call.onEvent.listen((event) {
      _handleEvent(event);
    });
  }

  void _handleEvent(VapiEvent event) {
    final label = event.label;
    final value = event.value;

    debugPrint('[Niva:event] $label');

    switch (label) {
      case 'call-start':
        _status = NivaStatus.active;
        _isSpeaking = false;
        _isMuted = false;
        WakelockPlus.enable();
        notifyListeners();
        break;

      case 'call-end':
        _status = NivaStatus.idle;
        _isSpeaking = false;
        _isMuted = false;
        _liveTranscript = null;
        _eventSub?.cancel();
        _eventSub = null;
        WakelockPlus.disable();
        notifyListeners();
        break;

      case 'speech-start':
        _isSpeaking = true;
        notifyListeners();
        break;

      case 'speech-end':
        _isSpeaking = false;
        notifyListeners();
        break;

      case 'message':
        _handleMessage(value);
        break;

      case 'error':
        debugPrint('[Niva:error] $value');
        _status = NivaStatus.idle;
        _isSpeaking = false;
        WakelockPlus.disable();
        notifyListeners();
        break;
    }
  }

  void _handleMessage(dynamic value) {
    if (value == null) return;

    Map<String, dynamic> msg;
    if (value is Map<String, dynamic>) {
      msg = value;
    } else if (value is String) {
      try {
        msg = jsonDecode(value) as Map<String, dynamic>;
      } catch (_) {
        return;
      }
    } else {
      try {
        msg = Map<String, dynamic>.from(value as Map);
      } catch (_) {
        return;
      }
    }

    final type = msg['type'] as String?;

    if (type == 'transcript') {
      final role = (msg['role'] as String?) ?? 'assistant';
      final content = (msg['transcript'] as String?) ?? '';
      final transcriptType = msg['transcriptType'] as String?;

      if (transcriptType == 'partial') {
        _liveTranscript = NivaTranscript(role: role, content: content);
        notifyListeners();
      } else if (transcriptType == 'final' && content.trim().isNotEmpty) {
        _liveTranscript = null;
        _messages.add(NivaTranscript(role: role, content: content.trim()));
        notifyListeners();
      }
      return;
    }

    if (type == 'function-call' || type == 'tool-calls') {
      _handleToolCalls(msg);
    }
  }

  void _handleToolCalls(Map<String, dynamic> msg) {
    final type = msg['type'] as String?;

    if (type == 'function-call') {
      final funcCall = msg['functionCall'] as Map<String, dynamic>?;
      if (funcCall == null) return;
      final name = funcCall['name'] as String?;
      final params = funcCall['parameters'] as Map<String, dynamic>? ?? {};
      _executeFunction(name, params);
    } else if (type == 'tool-calls') {
      final toolCallList = msg['toolCallList'] as List<dynamic>?;
      if (toolCallList == null) return;
      for (final call in toolCallList) {
        if (call is Map<String, dynamic>) {
          final func = call['function'] as Map<String, dynamic>?;
          if (func == null) continue;
          final name = func['name'] as String?;
          var args = func['arguments'];
          Map<String, dynamic> parsed = {};
          if (args is String) {
            try {
              parsed = jsonDecode(args) as Map<String, dynamic>;
            } catch (_) {}
          } else if (args is Map) {
            parsed = Map<String, dynamic>.from(args);
          }
          if (name == null) continue;
          _executeFunction(name, parsed);
        }
      }
    }
  }

  /// Delegates all tool execution to the shared ToolExecutor.
  void _executeFunction(String? name, Map<String, dynamic> args) {
    if (name == null) return;
    final ctx = _navContext;
    if (ctx == null) {
      debugPrint('[Niva:tools] No navigation context available');
      return;
    }
    // Delegate to shared ToolExecutor — both voice and chat use the same handlers
    ToolExecutor.executeFunction(name, args, ctx);
  }

  Future<void> startCall({
    required List<Expense> expenses,
    double? budget,
    String? userName,
    String currency = '₹',
    required List<GoalModel> goals,
    required List<Subscription> subscriptions,
    required int coins,
    required int xp,
    required int streak,
    required List<Contact> contacts,
  }) async {
    if (_status != NivaStatus.idle) return;
    if (!_service.isInitialized) {
      debugPrint('[Niva] Service not initialized');
      return;
    }

    final micStatus = await Permission.microphone.request();
    if (micStatus != PermissionStatus.granted) {
      debugPrint('[Niva] Microphone permission denied');
      _liveTranscript = NivaTranscript(
        role: 'system',
        content: 'Microphone permission is required to use voice Niva.',
      );
      notifyListeners();
      return;
    }

    _status = NivaStatus.connecting;
    _messages.clear();
    _liveTranscript = null;
    notifyListeners();

    try {
      final call = await _service.startCall(
        expenses: expenses,
        budget: budget,
        userName: userName,
        currency: currency,
        goals: goals,
        subscriptions: subscriptions,
        coins: coins,
        xp: xp,
        streak: streak,
        contacts: contacts,
      );

      if (call != null) {
        _subscribeToCallEvents(call);
      } else {
        _status = NivaStatus.idle;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Niva] startCall error: $e');
      _status = NivaStatus.idle;
      notifyListeners();
    }
  }

  Future<void> endCall() async {
    try {
      await _service.stopCall();
    } catch (e) {
      debugPrint('[Niva] endCall error: $e');
    }
    _eventSub?.cancel();
    _eventSub = null;
    _status = NivaStatus.idle;
    _isSpeaking = false;
    _isMuted = false;
    _liveTranscript = null;
    WakelockPlus.disable();
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    _service.setMuted(_isMuted);
    notifyListeners();
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _service.dispose();
    super.dispose();
  }
}
