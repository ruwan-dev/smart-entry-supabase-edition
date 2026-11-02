# Smart Entry (Android & Windows Desktop)

Tea collection, billing, and factory management application for Android and Windows Desktop.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development Guidelines

- **Code Comments**: Do not put Sinhala inside comments. All comments must be written in English.
- **Input Validation**: For numerical inputs (e.g., TextFields), enforce that they only accept numbers with up to two decimal points (using `FilteringTextInputFormatter`).
- **Deprecations**: Use `withValues()` instead of the deprecated `withOpacity()`. Use `initialValue` instead of `value` where applicable in form fields.
- **Logging**: Avoid using `print()` in production code. Use `debugPrint()` or a dedicated logging framework.
- **Null Safety**: Strictly adhere to Dart sound null safety.
- **Tenant Isolation**: Always enforce `.eq('organization_id', orgId)` / `AppState.currentOrganizationId` on all database operations.
- **Mobile Screen Scope**: On Android mobile, only 3 screens are available: **Dashboard**, **Customers**, and **Daily Entries** (Factories, Reports, and Settings are desktop-only).
