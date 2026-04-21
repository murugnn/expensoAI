import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:expenso/features/dashboard/dashboard_screen.dart';
import 'package:expenso/features/onboarding/history/history_screen.dart';
import 'package:expenso/features/ai_insights/ai_insights_screen.dart';
import 'package:expenso/features/settings/settings_screen.dart';
import 'package:expenso/features/add_expense/add_expense_sheet.dart';
import 'package:expenso/features/add_expense/add_bill_sheet.dart';
import 'package:expenso/services/receipt_scanner_service.dart';
import 'package:expenso/models/expense.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/features/tutorial/tutorial_helper.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/widgets/floating_update_icon.dart';
import 'package:expenso/widgets/niva_orb_widget.dart';
import 'package:expenso/providers/niva_voice_provider.dart';
import 'package:expenso/providers/subscription_provider.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/features/goals/services/goal_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _iconAnimation;
  OverlayEntry? _overlayEntry;
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _homeKey = GlobalKey();
  final GlobalKey _historyKey = GlobalKey();
  final GlobalKey _chartsKey = GlobalKey();
  final GlobalKey _settingsKey = GlobalKey();
  final GlobalKey _summaryKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkTutorialAndShow();
      context.read<AppSettingsProvider>().checkUpdate();
    });
  }



  void checkTutorialAndShow() {
    final settings = context.read<AppSettingsProvider>();
    // If not shown, show it.
    if (!settings.isTutorialShown) {
      // Ensure we are on the first tab if tutorial is triggered
      if (_selectedIndex != 0) {
        setTab(0);
      }
      
      // Small delay to ensure UI is ready
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showTutorial();
        }
      });
    }
  }

  void _showTutorial() {
    TutorialHelper.showTutorial(
      context,
      targets: TutorialHelper.createTargets(
        homeKey: _homeKey,
        historyKey: _historyKey,
        fabKey: _fabKey,
        chartsKey: _chartsKey,

        settingsKey: _settingsKey,
        summaryKey: _summaryKey,
      ),
      onFinish: (skipped) {
        context.read<AppSettingsProvider>().setTutorialShown(true);
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void setTab(int index) {
    setState(() => _selectedIndex = index);
  }

  void _toggleMenu() {
    if (_overlayEntry == null) {
      _showOverlay();
      _animationController.forward();
    } else {
      _closeMenu();
    }
  }

  void _closeMenu() async {
    await _animationController.reverse();
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);
    final renderBox = _fabKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final fabPosition = renderBox.localToGlobal(Offset.zero);
    final fabSize = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeMenu,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          
          // Menu Cards
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).size.height - fabPosition.dy + 16,
            child: Material(
              color: Colors.transparent,
              child: ScaleTransition(
                scale: CurvedAnimation(
                  parent: _animationController,
                  curve: Curves.easeOutBack,
                ),
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                   _buildActionCard(
                      context,
                      title: "Add Expense",
                      subtitle: "Log a new purchase",
                      icon: Icons.receipt_long,
                      color: Colors.orangeAccent,
                      onTap: () {
                        _closeMenu();
                        _showAddExpenseSheet(context);
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: "Scan Receipt (Beta)",
                      subtitle: "Auto-extract details extraction",
                      icon: Icons.qr_code_scanner,
                      color: Colors.blueAccent,
                      onTap: () {
                        _closeMenu();
                        _handleScan();
                      },
                    ),
                    _buildActionCard(
                      context,
                      title: "Set Budget",
                      subtitle: "Manage your limits",
                      icon: Icons.savings_outlined,
                      color: Colors.greenAccent,
                      onTap: () {
                        _closeMenu();
                        _showBudgetDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // FAB Copy (Animated)
          Positioned(
            top: fabPosition.dy,
            left: fabPosition.dx,
            width: fabSize.width,
            height: fabSize.height,
            child: FloatingActionButton(
              onPressed: _toggleMenu,
              shape: const CircleBorder(),
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: RotationTransition(
                turns: Tween(begin: 0.0, end: 0.125).animate(_iconAnimation), // 0.125 turns = 45 degrees
                child: Icon(
                  Icons.add,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 32,
                ),
              ),
            ),
          ),
          
          // Separate rotated icon manually if AnimatedIcon doesn't have a perfect + to x.
          // Using RotationTransition is safer for + to x.
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final screens = [
      DashboardScreen(
        onViewAll: () => setTab(1),
        summaryKey: _summaryKey,
      ),
      const HistoryScreen(),
      const AIInsightsScreen(),
      const SettingsScreen(),
    ];

    return Stack(
      children: [
        Scaffold(
          extendBody: true, // Crucial for the curve effect overlap
          body: Stack(
            children: [
              IndexedStack(
                index: _selectedIndex,
                children: screens,
              ),
              if (context.watch<AppSettingsProvider>().isUpdateAvailable)
                 Positioned(
                  left: 0,
                  top: 0,
                  right: 0,
                  bottom: 0,
                  child: FloatingUpdateIcon(
                    onTap: () async {
                       const url = "https://murugan-one.vercel.app/#projects-expenso";
                       if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
                         if (context.mounted) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("Could not launch update URL")),
                           );
                         }
                       }
                    },
                  ),
                 ),
              // Niva Transcript Bubble handled by GlobalNivaOverlay
            ],
          ),
          floatingActionButton: Consumer<NivaVoiceProvider>(
            builder: (context, provider, child) {
              final isActive = provider.status != NivaStatus.idle;
              
              if (isActive) {
                // The GlobalNivaOverlay renders the orb locally at this position.
                // We just provide an empty SizedBox here to hold the docking notch open.
                return const SizedBox(height: 80, width: 80);
              }

              return GestureDetector(
                onLongPress: () {
                  HapticFeedback.heavyImpact();
                  startNivaVoiceSession();
                },
                child: SizedBox(
                  height: 60,
                  width: 60,
                  child: FloatingActionButton(
                    key: _fabKey,
                    onPressed: _toggleMenu,
                    shape: const CircleBorder(),
                    backgroundColor: cs.primary,
                    elevation: 6,
                    child: Icon(Icons.add, color: cs.onPrimary, size: 32),
                  ),
                ),
              );
            },
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            shape: const CircularNotchedRectangle(),
            notchMargin: 8.0,
            height: 64,
            color: cs.surfaceContainer,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_filled, key: _homeKey),
                _buildNavItem(1, Icons.history_rounded, key: _historyKey),
                const SizedBox(width: 48), // Space for FAB
                _buildNavItem(2, Icons.bar_chart_rounded, key: _chartsKey),
                _buildNavItem(3, Icons.settings_rounded, key: _settingsKey),
              ],
            ),
          ),
        ),
        

      ],
    );
  }

  // --- Niva Voice Assistant ---

  void startNivaVoiceSession() {
    final nivaProvider = context.read<NivaVoiceProvider>();
    if (nivaProvider.status != NivaStatus.idle) return;

    nivaProvider.setNavContext(context);
    final expenseProvider = context.read<ExpenseProvider>();
    final authProvider = context.read<AuthProvider>();
    final gamificationProvider = context.read<GamificationProvider>();
    final subscriptionProvider = context.read<SubscriptionProvider>();
    final contactProvider = context.read<ContactProvider>();
    final goalService = context.read<GoalService>();

    final appSettingsProvider = context.read<AppSettingsProvider>();

    nivaProvider.startCall(
      expenses: expenseProvider.expenses,
      budget: expenseProvider.currentBudget?.amount,
      userName: authProvider.userName,
      goals: goalService.goals,
      subscriptions: subscriptionProvider.subscriptions,
      coins: gamificationProvider.coins,
      xp: gamificationProvider.xp,
      streak: gamificationProvider.currentStreak,
      contacts: contactProvider.contacts,
      customKey: appSettingsProvider.vapiKey,
    );
  }

  // --- Actions Logic ---

  void _showAddExpenseSheet(BuildContext context, {Expense? prefilledData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddExpenseSheet(prefilledData: prefilledData),
    );
  }

  Future<void> _handleScan() async {
    final scanner = ReceiptScannerService();
    try {
      final receipt = await scanner.scanReceipt();
      
      if (!mounted) return;

      if (receipt != null && receipt.items.isNotEmpty) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => AddBillSheet(receipt: receipt),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Could not identify items. Please try again with better lighting."),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Scan Error: $e")),
        );
      }
    }
  }

  // ... (keep _showBudgetDialog)

  Widget _buildNavItem(int index, IconData icon, {Key? key}) {
    final isSelected = _selectedIndex == index;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      key: key,
      decoration: isSelected
          ? BoxDecoration(
              shape: BoxShape.circle,
              color: isDark 
                  ? cs.primary.withValues(alpha: 0.15) 
                  : cs.primary.withValues(alpha: 0.1),
            )
          : null,
      child: IconButton(
        icon: Icon(
          icon,
          color: isSelected 
              ? (isDark ? Colors.white : cs.primary) 
              : cs.onSurfaceVariant,
          size: 28,
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          setTab(index);
        },
      ),
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context) {
     final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Budget"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Monthly Limit"),
        ),
        actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
           FilledButton(onPressed: () {
             final val = double.tryParse(controller.text);
             if (val != null) {
                final user = context.read<AuthProvider>().currentUser;
                if (user != null) {
                  context.read<ExpenseProvider>().setBudget(val, user.id);
                }
             }
             Navigator.pop(context);
           }, child: const Text("Save"))
        ],
      ),
    );
  }
}
