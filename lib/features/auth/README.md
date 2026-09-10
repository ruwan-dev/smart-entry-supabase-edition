# Auth Feature

## Overview
The `auth` feature handles the authentication and login process for the Smart Entry application. 

## Key Components
- **`LoginScreen` (`login_screen.dart`)**: The primary screen for authentication. It prompts the user for an admin password, which is verified against the `global_settings` table in the Supabase database. It features secure password entry, loading states, error handling via snackbars, and a clean, themed UI. Upon successful authentication, it navigates the user to the `DashboardScreen`.
