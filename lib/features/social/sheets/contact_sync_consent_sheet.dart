import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A privacy-first consent sheet shown before requesting OS contact permission.
class ContactSyncConsentSheet extends StatelessWidget {
  final VoidCallback onConsent;
  const ContactSyncConsentSheet({super.key, required this.onConsent});

  static Future<bool> show(BuildContext context) async {
    bool granted = false;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ContactSyncConsentSheet(
        onConsent: () {
          granted = true;
          Navigator.pop(context);
        },
      ),
    );
    return granted;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.contacts_outlined, size: 32, color: cs.primary),
          ),
          const SizedBox(height: 20),
          Text(
            'Find friends on Expenso',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            'We use secure hashing (SHA-256) to match your contacts. '
            'Your phone numbers and emails are never uploaded or stored on our servers. '
            'Only one-way hashes are compared, so your contacts stay private.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: cs.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outlined, size: 14, color: cs.primary),
              const SizedBox(width: 6),
              Text(
                'Privacy-first. Always.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                HapticFeedback.mediumImpact();
                onConsent();
              },
              child: const Text(
                'Allow contact access',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Not now',
              style: TextStyle(
                color: cs.onSurface.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
