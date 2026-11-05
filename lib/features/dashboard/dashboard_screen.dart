import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:smart_entry/core/customer/customer_form_screen.dart';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:smart_entry/core/factory/factory_form_screen.dart';
import 'package:smart_entry/core/entries/daily_entries_screen.dart';

import '../settings/settings_screen.dart';
import 'overview_screen.dart';
import '../reports/reports_screen.dart';

import '../../core/network_service.dart';
import '../../core/app_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import '../../core/localization/app_strings.dart';
import '../../core/localization/app_language.dart';
import '../../services/update_service.dart';

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
    // Check for app updates on Windows after the first frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdate(context);
    });
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
  }

  @override
  void dispose() {
    AppState.refreshTrigger.removeListener(_fetchOrgName);
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
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
        title: Text(AppStrings.logout),
        content: Text(AppStrings.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(AppStrings.yes),
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

  final Color primaryAppColor = const Color(0xFF1976D2);

  void _onItemTapped(int visualIndex, bool isMobile) {
    setState(() {
      if (isMobile) {
        // Map visual mobile index (0, 1, 2) to actual screens index (0, 1, 3)
        if (visualIndex == 0) _selectedIndex = 0;
        else if (visualIndex == 1) _selectedIndex = 1;
        else if (visualIndex == 2) _selectedIndex = 3;
      } else {
        _selectedIndex = visualIndex;
      }
    });
  }

  int _getVisualIndex(bool isMobile) {
    if (!isMobile) return _selectedIndex;
    
    // Map actual screens index (0, 1, 3) to visual mobile index (0, 1, 2)
    if (_selectedIndex == 0) return 0;
    if (_selectedIndex == 1) return 1;
    if (_selectedIndex == 3) return 2;
    return 0; // Default if somehow on an unsupported tab
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLanguageService.currentLanguage,
      builder: (context, currentLang, _) {
        final double screenWidth = MediaQuery.of(context).size.width;
        final bool isMobilePlatform =
            !kIsWeb && (Platform.isAndroid || Platform.isIOS);
        final bool isMobile = isMobilePlatform || screenWidth < 700;
        final bool showClock =
            !kIsWeb && Platform.isWindows && screenWidth >= 850;

        // On mobile: only tabs 0, 1, 3 (Overview, Customers, Entries) are supported.
        if (isMobile && (_selectedIndex == 2 || _selectedIndex > 3)) {
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

        // Desktop nav items (6)
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
            activeIcon: Icon(Icons.business_rounded, size: 28),
            icon: Icon(Icons.business_outlined, size: 24),
            label: 'Factories',
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
                      '${AppStrings.welcome}, ${_orgName.toUpperCase()}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (showClock) ...[
                  const _SriLankaClockBadge(),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
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
                            isOnline ? AppStrings.online : AppStrings.offline,
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
                tooltip: AppStrings.logout,
                onPressed: _logout,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: IndexedStack(
            key: ValueKey('main_screens_stack_${currentLang.code}'),
            index: _selectedIndex,
            children: [
              OverviewScreen(key: ValueKey('overview_${currentLang.code}')),
              CustomerFormScreen(key: ValueKey('customers_${currentLang.code}')),
              FactoryFormScreen(key: ValueKey('factories_${currentLang.code}')),
              DailyEntriesScreen(key: ValueKey('entries_${currentLang.code}')),
              ReportsScreen(key: ValueKey('reports_${currentLang.code}')),
              SettingsScreen(key: ValueKey('settings_${currentLang.code}')),
            ],
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _getVisualIndex(isMobile),
              onTap: (index) => _onItemTapped(index, isMobile),
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
      },
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
                    color: statusColor.withValues(alpha: (1 - _controller.value).clamp(0.0, 1.0)),
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
                      color: statusColor.withValues(alpha: 0.4),
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

class _SriLankaClockBadge extends StatefulWidget {
  const _SriLankaClockBadge();

  @override
  State<_SriLankaClockBadge> createState() => _SriLankaClockBadgeState();
}

class _SriLankaClockBadgeState extends State<_SriLankaClockBadge> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatSriLankaTime() {
    // Sri Lanka standard time is UTC+05:30
    final sl = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    final dayOfWeek = DateFormat('EEE', 'en_US').format(sl);
    final day = DateFormat('dd').format(sl);
    final month = DateFormat('MMM', 'en_US').format(sl).toLowerCase();
    final time = DateFormat('h.mm a', 'en_US').format(sl);
    return '$dayOfWeek,$day $month  $time';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            size: 13,
            color: Colors.white.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 6),
          Text(
            _formatSriLankaTime(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
