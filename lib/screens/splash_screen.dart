import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';
import 'dashboard/dashboard_screen.dart';
import 'distributors/distributor_list_screen.dart';
import 'bills/bill_list_screen.dart';
import 'settings/settings_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slipFade;
  late Animation<Offset> _slipSlide;
  late Animation<double> _badgeScale;
  late Animation<double> _wordmarkFade;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    // Slow continuous glow pulse behind the logo: tasteful breathe only.
    _pulseCtrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.repeat(reverse: true);
    _slipFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.44, curve: Curves.easeOut),
      ),
    );
    _slipSlide = Tween<Offset>(
      begin: const Offset(0, 0.45),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.44, curve: AppMotion.entrance),
      ),
    );
    _badgeScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.39, 0.78, curve: Curves.elasticOut),
      ),
    );
    _wordmarkFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.67, 1.0, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
    _timer = Timer(const Duration(milliseconds: 1050), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          AppMotion.pageRoute(const MainShell()),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: dark
                ? [AppColors.darkCard, AppColors.darkBg]
                : [AppColors.primary, AppColors.primaryLight],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _slipFade,
                child: SlideTransition(
                  position: _slipSlide,
                  child: ScaleTransition(
                    scale: _badgeScale,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ScaleTransition(
                          scale: _pulseScale,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.accent.withValues(alpha: 0.35),
                                  blurRadius: 48,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const BrandLogo(size: 110),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FadeTransition(
                opacity: _wordmarkFade,
                child: const Column(
                  children: [
                    Text(
                      'BILLMED',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 8,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Supplier Khata & Payments',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _billsFilterEpoch = 0;
  bool _billsOverdueOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      BackupService.autoBackup(ref.read(databaseProvider));
    }
  }

  void _openOverdueBills() {
    setState(() {
      _currentIndex = 1;
      _billsOverdueOnly = true;
      _billsFilterEpoch++;
    });
  }

  void _onTap(int i) {
    AppHaptics.select();
    setState(() {
      _currentIndex = i;
      // Any manual tab tap clears a deep-linked overdue filter so the Bills
      // tab can never get stuck filtered. Bump the epoch only when a filter
      // was actually active, forcing a fresh unfiltered list.
      if (_billsOverdueOnly) {
        _billsOverdueOnly = false;
        _billsFilterEpoch++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          DashboardScreen(onSeeOverdue: _openOverdueBills),
          BillListScreen(
            key: ValueKey('bills-$_billsFilterEpoch'),
            initialOverdueOnly: _billsOverdueOnly,
          ),
          const DistributorListScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardColor(context),
            borderRadius: BorderRadius.circular(24),
            border: AppShadow.cardBorder(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: Theme.of(context).brightness == Brightness.dark
                        ? 0.35
                        : 0.12),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _navItem(0, Icons.dashboard_rounded, 'Dashboard'),
                  _navItem(1, Icons.receipt_long_outlined, 'Bills'),
                  _navItem(2, Icons.business_outlined, 'Suppliers'),
                  _navItem(3, Icons.settings_outlined, 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    final accent = AppColors.accent;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: selected ? accent : AppColors.subtitleColor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? accent : AppColors.subtitleColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
