import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart'; // Ensure share_plus is in pubspec or use clipboard
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/services/referral_service.dart';
import 'package:expenso/theme.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  int _coins = 0;
  String? _referralCode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReferralData();
  }

  Future<void> _fetchReferralData() async {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;

    try {
      // 1. Check Metadata first (fastest)
      final meta = user.userMetadata;
      if (meta != null && meta['referral_code'] != null) {
         setState(() {
           _referralCode = meta['referral_code'];
           _coins = meta['coins'] is int ? meta['coins'] : 0;
         });
      }

      // 2. Fetch latest from public.user_stats (most accurate for coins)
      final response = await Supabase.instance.client
          .from('user_stats') 
          .select('coins, referral_code')
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _coins = response['coins'] ?? 0;
          _referralCode = response['referral_code'];
        });
      }
    } catch (e) {
      debugPrint("Error fetching referral data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _shareCode() {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null || _referralCode == null) return;

    final link = ReferralService().generateShareLink(_referralCode);
    Share.share("Join me on Expenso and track your expenses with AI! Use my code $_referralCode to get started.\n\n$link");
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Refer & Earn"),
        centerTitle: true,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
               // Coin Balance Card
               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   gradient: LinearGradient(
                     colors: [const Color(0xFF1E1E2C), const Color(0xFF0F0F16)],
                     begin: Alignment.topLeft,
                     end: Alignment.bottomRight,
                   ),
                   borderRadius: BorderRadius.circular(24),
                   border: Border.all(color: cs.primary.withOpacity(0.2)),
                   boxShadow: [
                     BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
                   ]
                 ),
                 child: Column(
                   children: [
                     const Text("Your Balance", style: TextStyle(color: Colors.white70, fontSize: 16)),
                     const SizedBox(height: 8),
                     Row(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                         Image.asset('assets/icons/coin.png', width: 32, height: 32, fit: BoxFit.contain),
                         const SizedBox(width: 8),
                         Text("$_coins Coins", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                       ],
                     ),
                   ],
                 ),
               ),

               const SizedBox(height: 32),

               // Info
               const Text("Invite Friends, Get Rewards!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               Text(
                 "Share your code with friends. When they install Expenso and add their first expense, you get 3000 coins!",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: cs.onSurfaceVariant),
               ),

               const SizedBox(height: 32),

               // Referral Code Box
               Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                 decoration: BoxDecoration(
                   color: cs.surfaceContainerHighest,
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: cs.outlineVariant),
                 ),
                 child: Row(
                   children: [
                     Expanded(
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           const Text("Your Referral Code", style: TextStyle(fontSize: 12)),
                           Text(_referralCode ?? "Generating...", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                         ],
                       ),
                     ),
                     IconButton(
                       icon: const Icon(Icons.copy),
                       onPressed: _referralCode == null ? null : () {
                         Clipboard.setData(ClipboardData(text: _referralCode!));
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Code copied!")));
                       },
                     )
                   ],
                 ),
               ),

               const SizedBox(height: 24),

               // Share Button
               SizedBox(
                 width: double.infinity,
                 child: FilledButton.icon(
                   onPressed: _referralCode == null ? null : _shareCode,
                   icon: const Icon(Icons.share),
                   label: const Text("Share Link"),
                   style: FilledButton.styleFrom(
                     padding: const EdgeInsets.symmetric(vertical: 16),
                   ),
                 ),
               ),
            ],
          ),
        ),
    );
  }
}
