import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../services/update_service.dart';
import '../services/notification_service.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
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
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  Timer? _timer;
  late Animation<double> _logoFade, _logoScl, _logoPulse;
  late Animation<Offset> _tagSlide;
  late Animation<double> _tagFade, _linerFade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 3600), vsync: this);

    _logoFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.4, curve: Curves.easeOutQuad));
    _logoScl = Tween<double>(begin: 0.15, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0, 0.55, curve: Curves.elasticOut)));
    _logoPulse = Tween<double>(begin: 1.0, end: 1.06).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 0.7, curve: Curves.easeInOut)));
    _tagFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 0.8, curve: Curves.easeIn));
    _tagSlide = Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 0.85, curve: Curves.easeOutCubic)));
    _linerFade = CurvedAnimation(parent: _ctrl, curve: const Interval(0.75, 1.0, curve: Curves.easeIn));

    _ctrl.forward();
    _initAndGo();
  }

  Future<void> _initAndGo() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
      try {
        NotificationService.init().then((_) => NotificationService.checkAndNotify(ref.read(databaseProvider)));
      } catch (_) {}
    });
    _timer = Timer(const Duration(milliseconds: 3600), () {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const _MainShell()));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0E27), Color(0xFF141852), Color(0xFF0D1442)],
          ),
        ),
        child: Stack(
          children: [
            // Particle background
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _ParticlePainter(_ctrl)))),

            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated logo
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScl,
                      child: AnimatedBuilder(
                        animation: _logoPulse,
                        builder: (ctx, ch) => Transform.scale(scale: _logoPulse.value, child: ch),
                      child: Container(
                        width: 150, height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [Color(0x1AFFFFFF), Color(0x0AFFFFFF)],
                            center: Alignment(-0.3, -0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00BFA5).withValues(alpha: 0.2),
                              blurRadius: 35, spreadRadius: 8,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(63),
                            child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tagline with slide + fade
                  SlideTransition(
                    position: _tagSlide,
                    child: FadeTransition(
                      opacity: _tagFade,
                      child: Column(
                        children: [
                          // Glowing text effect
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Colors.white, Color(0xFF5DF2D6)],
                            ).createShader(bounds),
                            child: const Text(
                              'BILLMED',
                              style: TextStyle(
                                fontSize: 42, fontWeight: FontWeight.w900,
                                color: Colors.white, letterSpacing: 10,
                                shadows: [Shadow(color: Colors.black38, blurRadius: 15, offset: Offset(0, 4))],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [Color(0xFF00BFA5), Color(0xFF009688)]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [BoxShadow(color: const Color(0xFF00BFA5).withValues(alpha: 0.3), blurRadius: 12)],
                            ),
                            child: const Text(
                              'Medical Shop Billing & Finance',
                              style: TextStyle(fontSize: 12, color: Colors.white, letterSpacing: 1.2, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Animated loading bar
                  FadeTransition(
                    opacity: _linerFade,
                    child: SizedBox(
                      width: 140, height: 3,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF00BFA5), Color(0xFF5DF2D6), Color(0xFF00BFA5)],
                          ).createShader(bounds),
                          child: const LinearProgressIndicator(
                            backgroundColor: Color(0x15FFFFFF),
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Particle background painter — animated floating dots
class _ParticlePainter extends CustomPainter {
  final Animation<double> anim;
  _ParticlePainter(this.anim);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final rng = math.Random(42);
    final t = anim.value;

    for (int i = 0; i < 25; i++) {
      final x = (rng.nextDouble() * size.width * 1.2 - size.width * 0.1);
      final y = (rng.nextDouble() * size.height * 1.2 - size.height * 0.1);
      final float = math.sin(t * 2 + i * 1.7) * 15;
      final size2 = 1.5 + rng.nextDouble() * 3;
      paint.color = const Color(0xFF5DF2D6).withValues(alpha: 0.06 + rng.nextDouble() * 0.08);
      canvas.drawCircle(Offset(x, y + float), size2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ===== Main Shell =====

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();
  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final screens = const [
    DashboardScreen(), BillListScreen(), DistributorListScreen(), SettingsScreen(),
  ];

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void dispose() { WidgetsBinding.instance.removeObserver(this); super.dispose(); }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) { try { BackupService.autoBackup(ref.read(databaseProvider)); } catch (_) {} }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accent,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 12,
        selectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Bills'),
          BottomNavigationBarItem(icon: Icon(Icons.business_outlined), label: 'Suppliers'),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
