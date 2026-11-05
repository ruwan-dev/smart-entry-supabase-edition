import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Codebase Scanner: Enforce Tenant Isolation on all Supabase queries in lib/', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib directory must exist');

    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    final List<String> violations = [];

    // Tables that require strict organization_id scoping
    final tenantScopedTables = [
      'factories',
      'customers',
      'daily_entries',
      'factory_entries',
      'factory_monthly_rates',
      'factory_finalized_bills',
      'factory_activity_logs',
      'finalized_bills',
      'monthly_rates',
      'monthly_summaries',
      'global_settings',
      'custom_items',
    ];

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        for (final table in tenantScopedTables) {
          if (line.contains(".from('$table')") || line.contains('.from("$table")')) {
            // Check context window of -25 to +25 lines around the query
            final contextStart = max(0, i - 25);
            final contextEnd = min(lines.length, i + 25);
            final context = lines.sublist(contextStart, contextEnd).join('\n');

            final hasOrgId = context.contains('organization_id') ||
                context.contains('orgId') ||
                context.contains('AppState.currentOrganizationId');

            if (!hasOrgId) {
              violations.add('${file.path}:${i + 1} - Query on table "$table" is missing organization_id scoping!');
            }
          }
        }
      }
    }

    if (violations.isNotEmpty) {
      fail('Found ${violations.length} tenant isolation violation(s):\n${violations.join('\n')}');
    }
  });

  test('Codebase Scanner: Enforce Primary Key & Upsert Scoping to prevent Cross-Tenant Collisions', () {
    final libDir = Directory('lib');
    final dartFiles = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();

    final List<String> upsertViolations = [];

    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      final lines = content.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('.upsert(')) {
          // Check context window of -15 to +15 lines around the upsert
          final contextStart = max(0, i - 15);
          final contextEnd = min(lines.length, i + 15);
          final context = lines.sublist(contextStart, contextEnd).join('\n');

          // Must either contain org-scoped ID, customer ID batch, or model toMap with org scoping
          final isScoped = context.contains('orgId') ||
              context.contains('organization_id') ||
              context.contains('organizationId') ||
              context.contains('finalizedBillsBatch') ||
              context.contains('item.toMap()');

          if (!isScoped) {
            upsertViolations.add('${file.path}:${i + 1} - Upsert call is not proven to be tenant-scoped!');
          }
        }
      }
    }

    if (upsertViolations.isNotEmpty) {
      fail('Found ${upsertViolations.length} insecure upsert(s):\n${upsertViolations.join('\n')}');
    }
  });
}
