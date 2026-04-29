import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:expenso/nav.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/services/referral_service.dart';

class RedeemCodeScreen extends StatefulWidget {
  const RedeemCodeScreen({super.key});

  @override
  State<RedeemCodeScreen> createState() => _RedeemCodeScreenState();
}

class _RedeemCodeScreenState extends State<RedeemCodeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _completeSetup({String? referralCode}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final user = auth.currentUser!;
    final supabase = Supabase.instance.client;

    // Derive display name from Google metadata or fallback
    final name = user.userMetadata?['full_name']?.toString() ??
        user.userMetadata?['name']?.toString() ??
        'User';
    final myReferralCode = ReferralService.generateReferralCode(name);

    // Validate the referral code if one was entered
    String? validatedCode;
    if (referralCode != null && referralCode.isNotEmpty) {
      final codeUpper = referralCode.toUpperCase();
      try {
        final res = await supabase
            .from('user_stats')
            .select('user_id')
            .eq('referral_code', codeUpper)
            .maybeSingle();
        if (res == null) {
          setState(() {
            _isLoading = false;
            _error = 'Invalid referral code';
          });
          return;
        }
        validatedCode = codeUpper;
      } catch (e) {
        setState(() {
          _isLoading = false;
          _error = 'Could not validate code';
        });
        return;
      }
    }

    try {
      await supabase.rpc('create_user_stats', params: {
        'p_user_id': user.id,
        'p_referral_code': myReferralCode,
        'p_referred_by': validatedCode,
      });

      // Sync Google display name into Supabase user metadata
      if (user.userMetadata?['name'] == null &&
          user.userMetadata?['full_name'] != null) {
        await supabase.auth.updateUser(
          UserAttributes(
              data: {'name': user.userMetadata!['full_name']}),
        );
      }

      auth.completeSetup();
      if (mounted) context.go(AppRoutes.dashboard);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Setup failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final displayName = auth.userName;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Welcome icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        cs.primary.withOpacity(0.15),
                        cs.secondary.withOpacity(0.10),
                      ],
                    ),
                  ),
                  child: Icon(Icons.celebration_rounded,
                      size: 56, color: cs.primary),
                ),
                const SizedBox(height: 24),

                Text(
                  'Welcome, $displayName!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account is almost ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 15, color: cs.onSurface.withOpacity(0.6)),
                ),

                const SizedBox(height: 40),

                // Referral code section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: cs.outlineVariant.withOpacity(0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.confirmation_number_outlined,
                              size: 20, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'Have a referral code?',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter it below to earn bonus coins for you and your friend!',
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onSurface.withOpacity(0.5)),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'e.g. MURUG-X7K',
                          prefixIcon: const Icon(Icons.vpn_key_outlined),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: cs.surface,
                          errorText: _error,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Apply button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _completeSetup(
                                referralCode:
                                    _codeController.text.trim());
                          },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Text('Apply & Continue',
                            style: TextStyle(fontSize: 16)),
                  ),
                ),

                const SizedBox(height: 12),

                // Skip button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            _completeSetup();
                          },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                          color: cs.outlineVariant.withOpacity(0.5)),
                    ),
                    child: Text('Skip',
                        style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurface.withOpacity(0.6))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
