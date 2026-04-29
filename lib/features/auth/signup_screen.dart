import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart'; // REQUIRED FOR AUTOFILL
import 'package:expenso/nav.dart';
import 'package:expenso/theme.dart';
import 'package:expenso/providers/auth_provider.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralController = TextEditingController();

  bool _termsAccepted = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Terms & Conditions"),
        content: const SingleChildScrollView(
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
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms & Conditions')),
      );
      return;
    }

    // 1. Tell OS to save the NEW credentials
    TextInput.finishAutofillContext();

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final error = await context.read<AuthProvider>().signup(
          _nameController.text.trim(),
          email,
          _passwordController.text,
          manualReferralCode: _referralController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (error == null) {
      context.go(AppRoutes.confirmEmail, extra: email);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              // 2. Wrap fields in AutofillGroup
              child: AutofillGroup(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      "Create Account",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Start tracking your expenses today",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _referralController,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "Referral Code (Optional)",
                        prefixIcon: const Icon(Icons.confirmation_number_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      // 3. Name Hints
                      autofillHints: const [AutofillHints.name],
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "Full Name",
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) =>
                          value!.isEmpty ? "Enter your name" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      // 4. Email Hints
                      autofillHints: const [AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "Email",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) =>
                          !value!.contains('@') ? "Enter a valid email" : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      // 5. New Password Hint (Different from Login!)
                      autofillHints: const [AutofillHints.newPassword],
                      keyboardType: TextInputType.visiblePassword,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () => _handleSignup(),
                      decoration: InputDecoration(
                        labelText: "Password",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value!.length < 6
                          ? "Password must be 6+ chars"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: _termsAccepted,
                          onChanged: (v) =>
                              setState(() => _termsAccepted = v ?? false),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface),
                                children: [
                                  const TextSpan(text: "I agree to the "),
                                  TextSpan(
                                    text: "Terms & Conditions",
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSignup,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text("Sign Up",
                              style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(height: 20),

                    // --- OR divider ---
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey.shade600)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('OR',
                              style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500)),
                        ),
                        Expanded(child: Divider(color: Colors.grey.shade600)),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- Google Sign-In ---
                    OutlinedButton.icon(
                      onPressed: _isLoading
                          ? null
                          : () async {
                              setState(() => _isLoading = true);
                              final auth = context.read<AuthProvider>();
                              final error = await auth.signInWithGoogle();
                              if (!mounted) return;
                              setState(() => _isLoading = false);
                              if (error != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(error),
                                      backgroundColor: Theme.of(context)
                                          .colorScheme
                                          .error),
                                );
                                return;
                              }
                              if (auth.isAuthenticated) {
                                context.go(AppRoutes.dashboard);
                              }
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outlineVariant),
                      ),
                      icon: Image.asset(
                        'assets/icons/google.png',
                        width: 22,
                        height: 22,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.g_mobiledata, size: 24),
                      ),
                      label: const Text('Continue with Google',
                          style: TextStyle(fontSize: 15)),
                    ),

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?"),
                        TextButton(
                          onPressed: () => context.go(AppRoutes.login),
                          child: const Text("Log In"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
