import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Status bar වර්ණය වෙනස් කිරීමට
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart';
import 'overview_screen.dart';
import '../reports/reports_screen.dart';

import '../../core/network_service.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  String _orgName = 'Smart Entry';

  @override
  void initState() {
    super.initState();
    _fetchOrgName();
    AppState.refreshTrigger.addListener(_fetchOrgName);
  }

  @override
  void dispose() {
    AppState.refreshTrigger.removeListener(_fetchOrgName);
    super.dispose();
  }

  Future<void> _fetchOrgName() async {
    try {
      final orgRes = await Supabase.instance.client
          .from('organizations')
          .select('name')
          .eq('id', AppState.currentOrganizationId.value ?? '')
          .maybeSingle();
      if (orgRes != null && mounted) {
        setState(() {
          _orgName = orgRes['name'] ?? 'Smart Entry';
        });
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _logout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of the system?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppState.currentOrganizationId.value = null;
      AppState.currentUsername.value = '';
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  // All 5 screens always alive in IndexedStack
  final List<Widget> _screens = [
    const OverviewScreen(), // 0. Overview
    const CustomerFormScreen(), // 1. Customers
    const DailyEntriesScreen(), // 2. Daily Entries
    const ReportsScreen(), // 3. Reports (PDF)
    const SettingsScreen(), // 4. Settings
  ];

  final Color primaryAppColor = const Color(0xFF1976D2);

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    // On mobile: only tabs 0, 1, 2 (Overview, Customers, Entries) are shown.
    // Reports (3) and Settings (4) are hidden from the nav bar.
    // If the current index is 3 or 4 and we switch to mobile, clamp to 0.
    if (isMobile && _selectedIndex > 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedIndex = 0);
      });
    }

    // Mobile nav items (3)
    const mobileItems = [
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.dashboard_rounded, size: 28),
        icon: Icon(Icons.dashboard_outlined, size: 24),
        label: 'Overview',
      ),
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.people_alt_rounded, size: 28),
        icon: Icon(Icons.people_alt_outlined, size: 24),
        label: 'Customers',
      ),
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.edit_document, size: 28),
        icon: Icon(Icons.edit_document, size: 24),
        label: 'Entries',
      ),
    ];

    // Desktop nav items (5)
    const desktopItems = [
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.dashboard_rounded, size: 28),
        icon: Icon(Icons.dashboard_outlined, size: 24),
        label: 'Overview',
      ),
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.people_alt_rounded, size: 28),
        icon: Icon(Icons.people_alt_outlined, size: 24),
        label: 'Customers',
      ),
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.edit_document, size: 28),
        icon: Icon(Icons.edit_document, size: 24),
        label: 'Entries',
      ),
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.analytics_rounded, size: 28),
        icon: Icon(Icons.analytics_outlined, size: 24),
        label: 'Reports',
      ),
      BottomNavigationBarItem(
        activeIcon: Icon(Icons.settings_rounded, size: 28),
        icon: Icon(Icons.settings_outlined, size: 24),
        label: 'Settings',
      ),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 40,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: primaryAppColor,
          statusBarIconBrightness: Brightness.light,
        ),
        elevation: 0,
        centerTitle: false,
        backgroundColor: primaryAppColor,
        foregroundColor: Colors.white,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome, ${_orgName.toUpperCase()}',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ValueListenableBuilder<bool>(
                valueListenable: NetworkService().connectionStatus,
                builder: (context, isOnline, child) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StatusDot(isOnline: isOnline),
                      const SizedBox(width: 8),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isOnline
                              ? const Color(0xFFA7F3D0)
                              : const Color(0xFFFECACA),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: isMobile ? _selectedIndex.clamp(0, 2) : _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primaryAppColor,
          unselectedItemColor: Colors.blueGrey.shade300,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
          showUnselectedLabels: true,
          items: isMobile ? mobileItems : desktopItems,
        ),
      ),
    );
  }
}

class _StatusDot extends StatefulWidget {
  final bool isOnline;
  const _StatusDot({required this.isOnline});

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color statusColor = widget.isOnline
        ? const Color(0xFF34D399)
        : const Color(0xFFF87171);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 14 * _controller.value,
                height: 14 * _controller.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: statusColor.withOpacity(1 - _controller.value),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.4),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
