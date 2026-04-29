import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';

// Feature Imports
import 'package:expenso/features/auth/confirm_email_screen.dart';
import 'package:expenso/features/auth/splash_screen.dart';
import 'package:expenso/features/auth/login_screen.dart';
import 'package:expenso/features/auth/signup_screen.dart';
import 'package:expenso/features/auth/redeem_code_screen.dart';
// DashboardScreen is now handled by MainScreen
import 'package:expenso/features/profile/profile_screen.dart';
import 'package:expenso/features/onboarding/walkthrough_screen.dart';
import 'package:expenso/features/onboarding/history/history_screen.dart';
import 'package:expenso/features/ai_insights/ai_insights_screen.dart';
import 'package:expenso/features/settings/settings_screen.dart';
import 'package:expenso/features/shop/rewards_shop_screen.dart';
import 'package:expenso/features/streak/streak_screen.dart';
import 'package:expenso/features/demon_fight/demon_fight_screen.dart';
import 'package:expenso/features/settings/manage_contacts_screen.dart';
import 'package:expenso/features/social/social_screen.dart';
import 'package:expenso/features/settings/manage_subscriptions_screen.dart';
import 'package:expenso/features/main_screen.dart';
import 'package:expenso/features/settings/referral_screen.dart';
import 'package:expenso/features/auth/reset_password_screen.dart';
import 'package:expenso/features/goals/screens/goals_screen.dart';
import 'package:expenso/features/agentic_chat/agentic_chat_screen.dart';

final GlobalKey<MainScreenState> mainScreenKey = GlobalKey<MainScreenState>();

class AppRoutes {
  static const String splash = '/';
  static const String walkthrough = '/walkthrough';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String dashboard = '/dashboard';
  static const String profile = '/profile';
  static const String history = '/history';
  static const String aiInsights = '/ai-insights';
  static const String settings = '/settings';
  static const String confirmEmail = '/confirm-email';
  static const String rewardsShop = '/rewards-shop';
  static const String streak = '/streak';
  static const String resetPassword = '/reset-password';
  static const String redeemCode = '/redeem-code';
  static const String chat = '/chat';

  static final router = GoRouter(
    initialLocation: splash,
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final settings = context.read<AppSettingsProvider>();

      // Wait for AuthProvider to finish its async init
      if (!auth.isReady) {
        return state.matchedLocation == splash ? null : splash;
      }

      final isLoggedIn = auth.isAuthenticated;
      final walkthroughEnabled = settings.walkthroughEnabled;

      final goingToWalkthrough = state.matchedLocation == walkthrough;
      final goingToLogin = state.matchedLocation == login;
      final goingToSignup = state.matchedLocation == signup;
      final goingToSplash = state.matchedLocation == splash;
      final goingToConfirmEmail = state.matchedLocation == confirmEmail;
      final goingToRedeemCode = state.matchedLocation == redeemCode;

      if (auth.isPasswordRecovery) {
        return resetPassword;
      }

      if (walkthroughEnabled) return goingToWalkthrough ? null : walkthrough;

      if (!isLoggedIn) {
        if (goingToLogin || goingToSignup || goingToConfirmEmail || state.matchedLocation == resetPassword) return null;
        return login;
      }

      // New OAuth user → needs to complete setup via redeem code screen
      if (auth.needsSetup) {
        return goingToRedeemCode ? null : redeemCode;
      }

      if (goingToSplash ||
          goingToLogin ||
          goingToSignup ||
          goingToWalkthrough ||
          goingToConfirmEmail ||
          goingToRedeemCode) {
        return dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(path: splash, builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: walkthrough,
        builder: (context, state) => const WalkthroughScreen(),
      ),
      GoRoute(path: login, builder: (context, state) => const LoginScreen()),
      GoRoute(path: signup, builder: (context, state) => const SignupScreen()),
      GoRoute(path: redeemCode, builder: (context, state) => const RedeemCodeScreen()),

      // Main Screen (Dashboard) holds the BottomNavBar
      GoRoute(path: dashboard, builder: (context, state) => MainScreen(key: mainScreenKey)),

      GoRoute(
          path: profile, builder: (context, state) => const ProfileScreen()),
      GoRoute(
          path: history, builder: (context, state) => const HistoryScreen()),
      GoRoute(
        path: aiInsights,
        builder: (context, state) => const AIInsightsScreen(),
      ),
      GoRoute(
        path: settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: confirmEmail,
        builder: (context, state) =>
            ConfirmEmailScreen(email: state.extra as String?),
      ),
      GoRoute(
        path: rewardsShop,
        builder: (context, state) => const RewardsShopScreen(),
      ),
      GoRoute(path: streak, builder: (context, state) => const StreakScreen()),

      // Demon fight screen stays accessible via push()
      GoRoute(
        path: '/demon-fight',
        builder: (context, state) => const DemonFightScreen(),
      ),
      GoRoute(
        path: '/settings/contacts',
        builder: (context, state) => const SocialScreen(),
      ),
      GoRoute(
        path: '/settings/subscriptions',
        builder: (context, state) => const ManageSubscriptionsScreen(),
      ),
      GoRoute(
        path: '/settings/referral',
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        path: resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/goals',
        builder: (context, state) => const GoalsScreen(),
      ),
    ],
  );
}

