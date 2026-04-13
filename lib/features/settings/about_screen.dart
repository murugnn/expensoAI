import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenso/theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  void _showTermsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Terms & Privacy Policy"),
        content: SingleChildScrollView(
          child: Text(
            """
Effective Date: 2026-02-01
App Name: EXPENSO  
Developer: WithoutChaya 

 Welcome to **EXPENSO** (“App”, “we”, “our”, “us”). By downloading, accessing, or using EXPENSO, you agree to these Terms & Conditions (“Terms”). If you do not agree, do not use the App.


---


 1) About EXPENSO

EXPENSO is an expense tracking application that helps users:

- record and organize expenses,

- view spending summaries and charts,

- optionally receive AI-generated insights based on the user’s expense data.


---


 2) Eligibility

You must be at least **13 years old** to use this App. If you are under the minimum age required in your country, you must use the App only with parental/guardian consent.


---


 3) User Responsibilities

By using EXPENSO, you agree that:

- you will enter information that is accurate to the best of your ability,

- you are responsible for maintaining the security of your device,

- you will not misuse or attempt to break the App.


---


 4) AI Insights Disclaimer

EXPENSO may provide AI-based insights and recommendations about your spending habits.


Important:

- AI insights are informational only.

- EXPENSO does not provide financial, investment, legal, or tax advice**.

- AI responses may be incomplete, incorrect, or outdated.


You should consult a qualified professional for important financial decisions.


---


 5) Data Storage & Backup

EXPENSO may store your data locally on your device (for example: expenses, categories, budgets, and preferences). If you uninstall the App or clear its data, you may lose stored information unless you have your own backup.


---


 6) Prohibited Use

You agree not to:

- use the App for unlawful purposes,

- attempt to hack, reverse engineer, or disrupt the App,

- misuse the AI feature for harmful, abusive, illegal, or misleading activity.


---


 7) Third-Party Services

EXPENSO may use third-party services (for example: AI APIs, analytics tools, or networking services) to provide certain features. These services may have their own terms and privacy policies.


---


 8) Intellectual Property

All branding, UI, designs, and code in EXPENSO are owned by the developer unless stated otherwise.


You may not copy, redistribute, or resell any part of the App without written permission.


---


 9) App Availability & Updates

We may update the App to improve features, fix bugs, or maintain compatibility. We do not guarantee uninterrupted availability and may suspend or discontinue the App at any time.


---


 10) Limitation of Liability

To the maximum extent allowed by law, EXPENSO and its developer will not be liable for:

- financial losses,

- incorrect calculations or missing data,

- AI insight errors,

- loss of data due to device issues, uninstalling the App, or storage resets.


Use the App at your own risk.


---


 11) Termination

We may suspend or terminate access to the App if you violate these Terms. You may stop using the App at any time by uninstalling it.


---


 12) Changes to These Terms

We may update these Terms from time to time. When updated, the “Effective Date” will be changed. Continued use of the App means you accept the updated Terms.


---


 13) Contact

For questions about these Terms, contact:


Privacy Policy


Effective Date: 2026-01-25

App Name: EXPENSO

Developer: WithoutChaya 


This Privacy Policy explains how **EXPENSO** (“App”, “we”, “our”, “us”) collects, uses, stores, and protects your information.


By using EXPENSO, you agree to this Privacy Policy.


---


 1) Information We Collect


 A) Information you enter in the app

EXPENSO may store the information you manually add, such as:

- expense amount, category, title, note

- date/time of expense

- payment mode (cash, UPI, card, etc.)

- budgets you set

- profile details (name, email, avatar) if the app supports it


 B) Device/technical information

EXPENSO may process basic technical information required for the app to function, such as:

- device type and OS version

- app version

- network connectivity status (only for online features)


---


 2) How We Use Your Information

We use your information to:

- display your expenses and summaries inside the app

- calculate totals, charts, and trends

- provide AI-generated insights (if you use the AI feature)

- improve app stability and fix bugs


---


 3) AI Feature & Data Sharing

If you use the AI Insights feature, EXPENSO may send relevant expense context (such as spending summaries or recent expenses) to a third-party AI service provider to generate insights.


We do not want you to enter sensitive personal data** such as:

- bank account numbers

- card numbers

- CVV/OTP/passwords

- Aadhaar/identity documents


EXPENSO is designed for expense tracking only.


---


 4) Where Your Data Is Stored

EXPENSO primarily stores your data locally on your device using local storage. But when connected to internet, the data is stored securely on cloud.


If you uninstall the app or clear app storage, your data may be deleted from the device.


---


 5) Do We Sell Your Data?

No. We do not sell your personal data.


---


 6) Data Security

We take reasonable steps to protect your data, but no system is 100% secure. You are responsible for keeping your device secure.


---


 7) Your Choices

You can:

- edit or delete expenses within the app

- uninstall the app to remove locally stored data

- avoid using the AI feature if you don’t want to send expense context to an AI service


---


 8) Children’s Privacy

EXPENSO is not intended for children under 13. We do not knowingly collect personal information from children.


---


 9) Changes to This Privacy Policy

We may update this Privacy Policy from time to time. The “Effective Date” will be updated. Continued use of the App means you accept the updated policy.


---


 10) Contact

If you have questions about this Privacy Policy, contact:


Email: murugnn9@gmail.com

Developer: WithoutChaya 
            """,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("About Expenso"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo from app assets
            Image.asset(
              'assets/icons/login.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, size: 50, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            
            // App Name
            Text(
              "Expenso",
              style: TextStyle(
                fontFamily: AppTheme.kDisplayFontFamily,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Version
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.hasData ? "v${snapshot.data!.version}" : "Loading...";
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    version,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.primary,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 48),

            // Info Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  _InfoLink(
                    icon: Icons.bug_report_outlined,
                    label: "Report a Bug",
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final uri = Uri(
                        scheme: 'mailto',
                        path: 'murugnn9@gmail.com',
                        query: 'subject=Expenso Bug Report&body=Describe the issue below:\n\n',
                      );
                      try {
                        await launchUrl(uri);
                      } catch (_) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email murugnn9@gmail.com to report a bug')),
                          );
                        }
                      }
                    },
                  ),
                  _InfoLink(
                    icon: Icons.privacy_tip_outlined,
                    label: "Privacy Policy",
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showTermsDialog(context);
                    },
                  ),
                ],
              ),
            ),

            const Spacer(),
            
            Text(
              "© 2026 Expenso Inc.",
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _InfoLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InfoLink({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
