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
}
