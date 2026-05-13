import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'database/database.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/distributors/distributor_list_screen.dart';
import 'services/update_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: BillMedApp()));
}

class BillMedApp extends StatelessWidget {
  const BillMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillMed',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  bool _checkedUpdate = false;

  final screens = const [
    DashboardScreen(),
    DistributorListScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedUpdate) {
      _checkedUpdate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UpdateService.checkForUpdates(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 16,
        unselectedFontSize: 14,
        selectedItemColor: AppTheme.primaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded, size: 28),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_rounded, size: 28),
            label: 'Distributors',
          ),
        ],
      ),
    );
  }
}
