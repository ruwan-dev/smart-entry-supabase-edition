import 'package:flutter_test/flutter_test.dart';
import 'package:smart_entry/core/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Factory Tenant Isolation Unit Tests', () {
    const String orgA = 'fb9ad045-9334-49ee-a06a-f86289525ae3';
    const String orgB = '11111111-1111-1111-1111-111111111111';

    setUp(() {
      AppState.currentOrganizationId.value = null;
    });

    test('AppState properly holds and notifies on currentOrganizationId change', () {
      String? observedOrg;
      AppState.currentOrganizationId.addListener(() {
        observedOrg = AppState.currentOrganizationId.value;
      });

      AppState.currentOrganizationId.value = orgA;
      expect(observedOrg, equals(orgA));

      AppState.currentOrganizationId.value = orgB;
      expect(observedOrg, equals(orgB));

      AppState.currentOrganizationId.value = null;
      expect(observedOrg, isNull);
    });

    test('Simulated Factory filtering strictly partitions data between organizations', () {
      final List<Map<String, dynamic>> mockDatabaseFactories = [
        {
          'id': 'factory-1-orgA',
          'refNumber': '1',
          'name': 'Rakwana Tea Factory',
          'organization_id': orgA,
        },
        {
          'id': 'factory-2-orgA',
          'refNumber': '2',
          'name': 'Pelmadulla Tea Factory',
          'organization_id': orgA,
        },
        {
          'id': 'factory-3-orgB',
          'refNumber': '1',
          'name': 'Deniyaya Tea Factory',
          'organization_id': orgB,
        },
      ];

      // Query as Org A
      AppState.currentOrganizationId.value = orgA;
      final orgAResults = mockDatabaseFactories.where(
        (f) => f['organization_id'] == AppState.currentOrganizationId.value,
      ).toList();

      expect(orgAResults.length, equals(2));
      expect(orgAResults.every((f) => f['organization_id'] == orgA), isTrue);
      expect(orgAResults.any((f) => f['name'] == 'Deniyaya Tea Factory'), isFalse);

      // Query as Org B
      AppState.currentOrganizationId.value = orgB;
      final orgBResults = mockDatabaseFactories.where(
        (f) => f['organization_id'] == AppState.currentOrganizationId.value,
      ).toList();

      expect(orgBResults.length, equals(1));
      expect(orgBResults.first['name'], equals('Deniyaya Tea Factory'));
      expect(orgBResults.any((f) => f['organization_id'] == orgA), isFalse);

      // Query when unauthenticated / null orgId
      AppState.currentOrganizationId.value = null;
      final unauthResults = mockDatabaseFactories.where(
        (f) => f['organization_id'] == (AppState.currentOrganizationId.value ?? ''),
      ).toList();
      expect(unauthResults, isEmpty);
    });

    test('Same RefNumber can exist in different organizations without conflict', () {
      final List<Map<String, dynamic>> mockFactories = [
        {
          'id': 'f1',
          'refNumber': '1',
          'name': 'Rakwana',
          'organization_id': orgA,
        },
      ];

      // Org A cannot create another factory with refNumber '1'
      String targetRef = '1';
      bool existsInOrgA = mockFactories.any(
        (f) => f['organization_id'] == orgA && f['refNumber'] == targetRef,
      );
      expect(existsInOrgA, isTrue);

      // Org B CAN create factory with refNumber '1' because it is scoped to Org B
      bool existsInOrgB = mockFactories.any(
        (f) => f['organization_id'] == orgB && f['refNumber'] == targetRef,
      );
      expect(existsInOrgB, isFalse);
    });

    test('Factory Entries filtering strictly enforces organization boundaries', () {
      final List<Map<String, dynamic>> mockEntries = [
        {
          'id': 'entry-1',
          'factoryId': 'factory-1-orgA',
          'organization_id': orgA,
          'date': '2026-10-01',
          'netWeight': 1250.0,
        },
        {
          'id': 'entry-2',
          'factoryId': 'factory-3-orgB',
          'organization_id': orgB,
          'date': '2026-10-01',
          'netWeight': 800.0,
        },
      ];

      // Filtering for Org A
      AppState.currentOrganizationId.value = orgA;
      final orgAEntries = mockEntries.where(
        (e) => e['organization_id'] == AppState.currentOrganizationId.value,
      ).toList();
      expect(orgAEntries.length, equals(1));
      expect(orgAEntries.first['netWeight'], equals(1250.0));

      // Filtering for Org B
      AppState.currentOrganizationId.value = orgB;
      final orgBEntries = mockEntries.where(
        (e) => e['organization_id'] == AppState.currentOrganizationId.value,
      ).toList();
      expect(orgBEntries.length, equals(1));
      expect(orgBEntries.first['netWeight'], equals(800.0));
    });

    test('Cross-tenant mutation prevention logic verifies organization ownership', () {
      final List<Map<String, dynamic>> mockFactories = [
        {
          'id': 'factory-1-orgA',
          'name': 'Rakwana',
          'organization_id': orgA,
        },
      ];

      // User in Org B attempts to delete Org A's factory
      AppState.currentOrganizationId.value = orgB;
      final deleteTargetId = 'factory-1-orgA';

      // Scoped delete matches both id AND organization_id
      mockFactories.removeWhere(
        (f) => f['id'] == deleteTargetId && f['organization_id'] == AppState.currentOrganizationId.value,
      );

      // Verification: 0 records removed, factory intact under Org A
      expect(mockFactories.length, equals(1));
      expect(mockFactories.first['id'], equals('factory-1-orgA'));
      expect(mockFactories.first['organization_id'], equals(orgA));
    });
  });
}
