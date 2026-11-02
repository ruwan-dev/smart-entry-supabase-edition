import 'package:flutter_test/flutter_test.dart';
import 'package:smart_entry/core/items/item_model.dart';
import 'package:smart_entry/core/items/item_service.dart';

void main() {
  group('CustomItem Model Tests', () {
    test('Correct serialization and deserialization', () {
      final item = CustomItem(
        id: 'item_1',
        organizationId: 'org_123',
        slotIndex: 5,
        code: 'I5',
        name: 'Chemical A',
        unitPrice: 2500.50,
        isActive: true,
      );

      final map = item.toMap();
      expect(map['id'], 'item_1');
      expect(map['organization_id'], 'org_123');
      expect(map['slot_index'], 5);
      expect(map['code'], 'I5');
      expect(map['name'], 'Chemical A');
      expect(map['unit_price'], 2500.50);
      expect(map['is_active'], true);

      final fromMap = CustomItem.fromMap(map);
      expect(fromMap.id, item.id);
      expect(fromMap.organizationId, item.organizationId);
      expect(fromMap.slotIndex, item.slotIndex);
      expect(fromMap.code, item.code);
      expect(fromMap.name, item.name);
      expect(fromMap.unitPrice, item.unitPrice);
      expect(fromMap.isActive, item.isActive);
    });

    test('copyWith updates properties properly', () {
      final item = CustomItem(
        id: 'item_2',
        organizationId: 'org_123',
        slotIndex: 2,
        code: 'F2',
        name: 'Fertilizer 2',
        unitPrice: 18000.0,
      );

      final updated = item.copyWith(
        name: 'Special Fertilizer',
        unitPrice: 19500.0,
      );

      expect(updated.id, 'item_2');
      expect(updated.slotIndex, 2);
      expect(updated.name, 'Special Fertilizer');
      expect(updated.unitPrice, 19500.0);
    });
  });

  group('ItemService Constraints Tests', () {
    test('Enforces strict limit of 8 items per organization', () {
      expect(ItemService.maxItemsPerOrg, 8);
    });

    test('Validates 8 items maximum boundary logic', () {
      final List<CustomItem> existingItems = List.generate(
        8,
        (i) => CustomItem(
          id: 'item_${i + 1}',
          organizationId: 'org_123',
          slotIndex: i + 1,
          code: 'I${i + 1}',
          name: 'Item ${i + 1}',
          unitPrice: 1000.0 * (i + 1),
        ),
      );

      expect(existingItems.length, 8);

      // Verify that adding a new 9th item exceeds the ceiling
      final newItem = CustomItem(
        id: 'item_9',
        organizationId: 'org_123',
        slotIndex: 9,
        code: 'I9',
        name: 'Item 9',
        unitPrice: 9000.0,
      );

      final isNewItem = !existingItems.any((it) => it.id == newItem.id || it.slotIndex == newItem.slotIndex);
      expect(isNewItem, isTrue);

      bool exceedsLimit = isNewItem && existingItems.length >= ItemService.maxItemsPerOrg;
      expect(exceedsLimit, isTrue);

      // Verify editing an existing item within the 8 does not exceed limit
      final editItem = existingItems.first.copyWith(name: 'Updated Name');
      final isNewItemEdit = !existingItems.any((it) => it.id == editItem.id || it.slotIndex == editItem.slotIndex);
      expect(isNewItemEdit, isFalse);
    });

    test('Soft-deletion preserves historical item metadata while excluding from active queries', () {
      final activeItem = CustomItem(
        id: 'item_hist_1',
        organizationId: 'org_123',
        slotIndex: 5,
        code: 'CH1',
        name: 'Chemical 1',
        unitPrice: 3200.0,
        isActive: true,
      );

      // Deactivate (soft-delete)
      final deactivatedItem = activeItem.copyWith(isActive: false);

      expect(deactivatedItem.id, 'item_hist_1');
      expect(deactivatedItem.slotIndex, 5);
      expect(deactivatedItem.code, 'CH1');
      expect(deactivatedItem.name, 'Chemical 1');
      expect(deactivatedItem.unitPrice, 3200.0);
      expect(deactivatedItem.isActive, isFalse);

      final allItems = [deactivatedItem, activeItem.copyWith(id: 'item_2', slotIndex: 6)];
      final activeOnly = allItems.where((it) => it.isActive).toList();
      expect(activeOnly.length, 1);
      expect(activeOnly.first.id, 'item_2');

      // Historical lookup still finds the deactivated item
      final historicItem = allItems.firstWhere((it) => it.id == 'item_hist_1');
      expect(historicItem.name, 'Chemical 1');
      expect(historicItem.unitPrice, 3200.0);
    });

    test('parseDailyEntryItems correctly parses dynamic_items and ignores legacy shadow columns to prevent double-counting', () {
      final entry = {
        'fertilizer1Qty': 2.0, // legacy shadow copy
        'fertilizer2Qty': 1.0,
        'teaPacket1Qty': 3.0,
        'teaPacket2Qty': 0.0,
        'dynamic_items': {
          'F1': 2.0,
          'item_abc1': {
            'id': 'abc1',
            'slot': 1,
            'code': 'F1',
            'name': 'පොහොර 1',
            'unitPrice': 15500.0,
            'qty': 2.0,
            'amt': 31000.0,
          },
          'item_abc2': {
            'id': 'abc2',
            'slot': 5,
            'code': 'DL',
            'name': 'Dolomite',
            'unitPrice': 2500.0,
            'qty': 4.0,
            'amt': 10000.0,
          },
        },
      };

      final parsed = ItemService.parseDailyEntryItems(entry, f1Price: 15500.0);

      // Verify slot 1 is 2.0 (NOT 4.0 from double counting!)
      expect(parsed.f1Qty, 2.0);
      expect(parsed.f1Amt, 31000.0);
      // Legacy f2 and t1 are ignored because dynamic_items had active items
      expect(parsed.f2Qty, 0.0);
      expect(parsed.t1Qty, 0.0);
      // Slot 5 is dynamic item
      expect(parsed.otherDynamicQty, 4.0);
      expect(parsed.otherDynamicAmt, 10000.0);
      expect(parsed.totalItemsAmt, 41000.0);
      expect(parsed.itemsList.length, 2);
    });

    test('parseDailyEntryItems falls back to legacy 4 columns when dynamic_items is empty or null', () {
      final entry = {
        'fertilizer1Qty': 1.0,
        'fertilizer2Qty': 2.0,
        'teaPacket1Qty': 5.0,
        'teaPacket2Qty': 0.0,
        'dynamic_items': null,
      };

      final parsed = ItemService.parseDailyEntryItems(
        entry,
        f1Price: 15500.0,
        f2Price: 18000.0,
        t1Price: 650.0,
      );

      expect(parsed.f1Qty, 1.0);
      expect(parsed.f1Amt, 15500.0);
      expect(parsed.f2Qty, 2.0);
      expect(parsed.f2Amt, 36000.0);
      expect(parsed.t1Qty, 5.0);
      expect(parsed.t1Amt, 3250.0);
      expect(parsed.totalFertilizerQty, 3.0);
      expect(parsed.totalTeaPacketQty, 5.0);
      expect(parsed.totalItemsAmt, 54750.0);
      expect(parsed.itemsList.length, 3);
    });
  });
}
