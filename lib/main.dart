import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:expenso/services/supabase_config.dart';
import 'package:expenso/services/notification_service.dart';
import 'package:expenso/services/launch_intent_service.dart';
import 'package:expenso/services/launch_intent_service.dart';
import 'package:expenso/services/ml_service.dart'; // Import ML Service
import 'package:expenso/services/ml_service.dart'; // Import ML Service
import 'package:expenso/services/referral_service.dart';
import 'package:expenso/services/sms_service.dart';
import 'package:expenso/features/goals/services/goal_service.dart';

import 'package:expenso/theme.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/widgets/sms_expense_dialog.dart';
import 'package:expenso/widgets/snow_overlay.dart';
import 'package:expenso/widgets/wave_overlay.dart';
import 'package:expenso/widgets/light_sweep_overlay.dart';

import 'package:expenso/features/updater/services/update_service.dart';
import 'package:expenso/features/updater/widgets/update_dialog.dart';
// Providers
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/demon_game_provider.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/providers/subscription_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('expenso_settings');

  await dotenv.load(fileName: ".env");
  await NotificationService.instance.init();
  await SmsService().init();
  await ReferralService().init(); // Initialize Referral Service

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // REMOVED: expenseProvider usage here (it doesn't exist yet!)

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppSettingsProvider()),
        ChangeNotifierProxyProvider<AuthProvider, GamificationProvider>(
          create: (_) => GamificationProvider(),
          update: (_, auth, game) => game!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, DemonGameProvider>(
          create: (_) => DemonGameProvider(),
          update: (_, auth, demon) => demon!..updateAuth(auth),
        ),
        ChangeNotifierProxyProvider<AuthProvider, ContactProvider>(
          create: (_) => ContactProvider(),
          update: (_, auth, contacts) => contacts!..updateAuth(auth),
        ),
        ChangeNotifierProvider(
          create: (_) => GoalService(),
        ),
        ChangeNotifierProxyProvider4<AuthProvider, GamificationProvider,
            DemonGameProvider, GoalService, ExpenseProvider>(
          create: (_) => ExpenseProvider(),
          update: (_, auth, game, demon, goals, expense) =>
              expense!..update(auth, game, demon, goals),
        ),
        ChangeNotifierProxyProvider2<AuthProvider, ExpenseProvider,
            SubscriptionProvider>(
          create: (_) => SubscriptionProvider(),
          update: (_, auth, expense, sub) => sub!..update(auth, expense),
        ),
      ],
      child: const ExpensoApp(),
    );
  }
}

class ExpensoApp extends StatefulWidget {
  const ExpensoApp({super.key});

  @override
  State<ExpensoApp> createState() => _ExpensoAppState();
}

class _ExpensoAppState extends State<ExpensoApp> {
  bool _handledLaunch = false;
  bool _mlInitialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 1. Force the providers to wake up
      final authProvider = context.read<AuthProvider>();

      // 2. Initialize ML Service here (Safe place)
      if (authProvider.currentUser != null && !_mlInitialized) {
        final expenseProvider = context.read<ExpenseProvider>();

        // Wait for expenses to be loaded if they aren't already
        if (expenseProvider.expenses.isEmpty) {
          await expenseProvider.loadExpenses();
        }

        // Initialize ML with loaded expenses
        await MLService().init(expenseProvider.expenses);
        _mlInitialized = true;
      }

      // 3. Handle Launch Intents
      if (_handledLaunch) return;
      _handledLaunch = true;

      final route = await LaunchIntentService.getLaunchRoute();
      if (route == 'dashboard') {
        AppRoutes.router.go('/dashboard');
      }

      // 4. Check for Updates
      _checkForUpdates();
    });
    
    // 4. Listen for SMS (Queue System)
    SmsService().smsStream.listen((data) {
      if (!mounted) return;
      
      final settings = context.read<AppSettingsProvider>();
      if (!settings.smsTrackingEnabled) return;

      _smsQueue.add(data);
      _processSmsQueue();
    });
  }

  // Queue to hold pending SMS data
  final List<Map<String, dynamic>> _smsQueue = [];
  bool _isShowingSmsDialog = false;

  Future<void> _checkForUpdates() async {
    final updateService = UpdateService();
    final versionModel = await updateService.checkForUpdate();
    
    if (versionModel != null) {
      if (!mounted) return;
      // Find the top-most context using router
      final ctx = AppRoutes.router.routerDelegate.navigatorKey.currentContext;
      if (ctx == null) return;

      showDialog(
        context: ctx,
        barrierDismissible: !versionModel.forceUpdate,
        builder: (context) => UpdateDialog(versionModel: versionModel),
      );
    }
  }

  void _processSmsQueue() async {
    if (_isShowingSmsDialog || _smsQueue.isEmpty) return;
    if (!mounted) return;

    final ctx = AppRoutes.router.routerDelegate.navigatorKey.currentContext;
    if (ctx == null) return;

    _isShowingSmsDialog = true;
    final data = _smsQueue.removeAt(0);

    await showDialog(
      context: ctx,
      barrierDismissible: false, // Force user to Ignore or Add
      builder: (context) => SmsExpenseDialog(
        amount: data['amount'],
        merchant: data['merchant'],
        date: data['date'],
      ),
    );

    _isShowingSmsDialog = false;
    // Process next item
    _processSmsQueue();
  } 
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();

    return MaterialApp.router(
      title: 'Expenso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme(isAmoled: settings.isAmoled),
      themeMode: settings.themeMode,
      routerConfig: AppRoutes.router,
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            
            // Global Ambient Overlays
            Consumer2<AppSettingsProvider, GamificationProvider>(
              builder: (context, settings, game, _) {
                if (!game.isPremium) return const SizedBox.shrink();

                switch (settings.ambientEffect) {
                  case 'snow':
                    if (game.ownsSnowTheme) {
                      return const SnowOverlay(isEnabled: true);
                    }
                    return const SizedBox.shrink();
                  case 'wave':
                    if (game.ownsWaveTheme) {
                      return const WaveOverlay();
                    }
                    return const SizedBox.shrink();
                  case 'light_sweep':
                    if (game.ownsLightSweepTheme) {
                      return const CrystalSparkleOverlay();
                    }
                    return const SizedBox.shrink();
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
