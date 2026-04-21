import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NivaUtils {
  static void showNivaConnectDialog(BuildContext context, {bool isCreditExceeded = false}) {
    final settings = context.read<AppSettingsProvider>();
    final controller = TextEditingController(text: settings.vapiKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isCreditExceeded ? "Niva Credits Exceeded" : "Niva Voice Connect"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCreditExceeded) ...[
                const Text(
                  "It looks like your free VAPI credits have run out. To continue using Niva, please generate a new API key.",
                  style: TextStyle(fontSize: 14, color: Colors.orangeAccent),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                "Go to vapi.ai, sign in, and go to the API section to get your Public Key.",
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () async {
                  final url = Uri.parse('https://dashboard.vapi.ai/');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                icon: const Icon(Icons.open_in_browser, size: 18),
                label: const Text("Open VAPI Dashboard"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: "VAPI Public Key",
                  hintText: "Enter your public key",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                settings.setVapiKey(controller.text.trim());
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Niva API Key updated! Try waking her up again.")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}
