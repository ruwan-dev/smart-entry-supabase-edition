# Settings Feature

## Overview
The `settings` feature acts as the administration panel for the application, allowing users to configure global variables, manage security, and perform data backups.

## Key Components
- **`SettingsScreen` (`settings_screen.dart`)**: The central settings interface. Its main responsibilities include:
  - **Password Management**: Allows the admin to change the application password.
  - **Global Prices**: Configuration of default prices for items like Fertilizer 1, Fertilizer 2, Tea Packet 1, and Tea Packet 2.
  - **Monthly Rates**: Management of dynamic monthly rates such as tea rates and transport rates.
  - **Data Backup**: Provides functionality to export and download the complete database (customers, entries, settings, summaries) as a JSON backup file.
