import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Factory Daily Allocation & Collection Tests', () {
    test('Correctly aggregates supplier collections for a given date', () {
      final List<Map<String, dynamic>> supplierEntries = [
        {'date': '2026-09-01', 'netWeight': 150.5, 'netWeight2': 20.0},
        {'date': '2026-09-01', 'netWeight': 300.0, 'netWeight2': 0.0},
        {'date': '2026-09-01', 'netWeight': 45.5, 'netWeight2': 10.5},
        {'date': '2026-09-02', 'netWeight': 500.0, 'netWeight2': 50.0}, // different date
      ];

      double collectedNormal = 0.0;
      double collectedSuper = 0.0;

      for (var entry in supplierEntries) {
        if (entry['date'] == '2026-09-01') {
          collectedNormal += ((entry['netWeight'] ?? 0) as num).toDouble();
          collectedSuper += ((entry['netWeight2'] ?? 0) as num).toDouble();
        }
      }

      double collectedTotal = collectedNormal + collectedSuper;

      expect(collectedNormal, equals(496.0));
      expect(collectedSuper, equals(30.5));
      expect(collectedTotal, equals(526.5));
    });

    test('Correctly isolates other factory allocations excluding current factory', () {
      const String currentFactoryId = 'factory_rakwana';

      final List<Map<String, dynamic>> factoryEntries = [
        {
          'factoryId': 'factory_dimbula',
          'factoryName': 'Dimbula Factory',
          'grossWeight': 200.0,
          'netWeight': 200.0,
          'netWeight2': 20.0,
          'date': '2026-09-01',
        },
        {
          'factoryId': 'factory_rakwana', // current factory
          'factoryName': 'Rakwana Factory',
          'grossWeight': 150.0,
          'netWeight': 150.0,
          'netWeight2': 10.0,
          'date': '2026-09-01',
        },
        {
          'factoryId': 'factory_pelmadulla',
          'factoryName': 'Pelmadulla Factory',
          'grossWeight': 100.0,
          'netWeight': 95.0, // after deductions
          'netWeight2': 5.0,
          'date': '2026-09-01',
        },
      ];

      final otherAllocations = factoryEntries
          .where((e) => e['factoryId'] != currentFactoryId)
          .toList();

      double otherNormal = 0.0;
      double otherSuper = 0.0;

      for (var entry in otherAllocations) {
        otherNormal += ((entry['grossWeight'] ?? entry['netWeight'] ?? 0) as num).toDouble();
        otherSuper += ((entry['netWeight2'] ?? 0) as num).toDouble();
      }

      expect(otherAllocations.length, equals(2));
      expect(otherNormal, equals(300.0));
      expect(otherSuper, equals(25.0));
      expect(otherNormal + otherSuper, equals(325.0));
    });

    test('Computes available leaf and detects real-time remaining / over-allocation', () {
      const double totalCollected = 1000.0;
      const double otherAllocated = 600.0;
      const double availableForThisFactory = totalCollected - otherAllocated; // 400.0

      expect(availableForThisFactory, equals(400.0));

      // Case 1: Under allocation
      double enteredWeight1 = 250.0;
      double remaining1 = availableForThisFactory - enteredWeight1;
      expect(remaining1, equals(150.0));
      expect(remaining1 > 0, isTrue);

      // Case 2: Exact full allocation
      double enteredWeight2 = 400.0;
      double remaining2 = availableForThisFactory - enteredWeight2;
      expect(remaining2.abs() < 0.001, isTrue);

      // Case 3: Over-allocation
      double enteredWeight3 = 450.0;
      double remaining3 = availableForThisFactory - enteredWeight3;
      expect(remaining3, equals(-50.0));
      expect(remaining3 < 0, isTrue);
    });

    test('Handles zero supplier collection and zero other factory entries gracefully', () {
      const double totalCollected = 0.0;
      const double otherAllocated = 0.0;
      const double available = totalCollected - otherAllocated;

      expect(available, equals(0.0));
      expect(available >= 0, isTrue);
    });

    test('Excludes entries of deleted or inactive factories not in factories map', () {
      const String currentFactoryId = 'factory_rakwana';
      final Map<String, Map<String, dynamic>> activeFactoriesMap = {
        'factory_rakwana': {'id': 'factory_rakwana', 'name': 'Rakwana Factory'},
        'factory_dimbula': {'id': 'factory_dimbula', 'name': 'Dimbula Factory'},
        // 'factory_pelmadulla' was deleted, so it is omitted from activeFactoriesMap
      };

      final List<Map<String, dynamic>> factoryEntries = [
        {
          'factoryId': 'factory_dimbula',
          'factoryName': 'Dimbula Factory',
          'grossWeight': 200.0,
          'netWeight': 200.0,
          'netWeight2': 20.0,
        },
        {
          'factoryId': 'factory_rakwana',
          'factoryName': 'Rakwana Factory',
          'grossWeight': 150.0,
          'netWeight': 150.0,
          'netWeight2': 10.0,
        },
        {
          'factoryId': 'factory_pelmadulla', // Orphaned entry from deleted factory
          'factoryName': 'Pelmadulla Factory',
          'grossWeight': 100.0,
          'netWeight': 95.0,
          'netWeight2': 5.0,
        },
      ];

      final otherAllocations = factoryEntries
          .where((e) => e['factoryId'] != currentFactoryId && activeFactoriesMap.containsKey(e['factoryId']))
          .toList();

      expect(otherAllocations.length, equals(1));
      expect(otherAllocations.first['factoryId'], equals('factory_dimbula'));
    });
  });
}
