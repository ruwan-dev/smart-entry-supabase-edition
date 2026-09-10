# Dashboard Feature

## Overview
The `dashboard` feature serves as the primary navigation hub and main interface of the application after a successful login.

## Key Components
- **`DashboardScreen` (`dashboard_screen.dart`)**: The root screen of the dashboard. It implements a `BottomNavigationBar` to seamlessly switch between the core sections of the app (Overview, Customers, Entries, Reports, and Settings). It also includes a real-time network status indicator in the app bar.
- **`OverviewScreen` (`overview_screen.dart`)**: Provides a high-level summary and vital statistics for the current operations.
- **`OutstandingListScreen` (`outstanding_list_screen.dart`)**: Displays a list of outstanding balances and pending collections for easy tracking.
