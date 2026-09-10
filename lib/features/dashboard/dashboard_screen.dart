import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Status bar වර්ණය වෙනස් කිරීමට
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart'; 
import 'overview_screen.dart'; 
import '../reports/reports_screen.dart'; 

import '../../core/network_service.dart'; 

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; 

  final List<Widget> _screens = [
    const OverviewScreen(),     // 0. Overview
    const CustomerFormScreen(), // 1. Customers
    const DailyEntriesScreen(), // 2. Daily Entries
    const ReportsScreen(),      // 3. Reports (PDF)
    const SettingsScreen(),     // 4. Settings
  ];

  // App එකේ ප්‍රධාන Theme එක නිල් (Blue)
  final Color primaryAppColor = const Color(0xFF1976D2); 

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        // දුරකථනයේ ඉහළම තීරුව (Status Bar) නිල් පැහැ ගැන්වීම
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: primaryAppColor,
          statusBarIconBrightness: Brightness.light, 
        ),
        elevation: 0,
        centerTitle: false,
        backgroundColor: primaryAppColor, // AppBar හි ප්‍රධාන වර්ණය නිල් (Blue)
        foregroundColor: Colors.white,    // අකුරු වල වර්ණය සුදු
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Smart Entry', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                          color: isOnline ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            )
          ]
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed, 
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: primaryAppColor, // Active Icon එකේ වර්ණය නිල්
          unselectedItemColor: Colors.blueGrey.shade300, 
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 10),
          showUnselectedLabels: true,
          items: const [
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
              activeIcon: Icon(Icons.picture_as_pdf_rounded, size: 28),
              icon: Icon(Icons.picture_as_pdf_outlined, size: 24),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.settings_rounded, size: 28),
              icon: Icon(Icons.settings_outlined, size: 24),
              label: 'Settings',
            ),
          ],
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

class _StatusDotState extends State<_StatusDot> with SingleTickerProviderStateMixin {
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
    Color statusColor = widget.isOnline ? const Color(0xFF34D399) : const Color(0xFFF87171);

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
                    BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 3),
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