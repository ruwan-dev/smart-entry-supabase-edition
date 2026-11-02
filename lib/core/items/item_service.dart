import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import '../localization/app_strings.dart';
import 'item_model.dart';

class ItemService {
  static const int maxItemsPerOrg = 8;
  static final Set<String> _attemptedMigrations = {};

  /// Fetches items for the specified organization (or current active org).
  /// Enforces maximum 8 active items per organization.
  /// If [activeOnly] is true (default), returns only active items.
  /// If [activeOnly] is false, returns all items including historical/deactivated items.
  static Future<List<CustomItem>> getItems({
    String? organizationId,
    bool activeOnly = true,
  }) async {
    final orgId = organizationId ?? AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) return _getDefaultItems(orgId, null);

    // 1. Try querying dedicated 'items' table
    try {
      var query = Supabase.instance.client
          .from('items')
          .select()
          .eq('organization_id', orgId);

      if (activeOnly) {
        query = query.eq('is_active', true);
      }

      final response = await query.order('slot_index', ascending: true);

      if (response.isNotEmpty) {
        final list = response.map((m) => CustomItem.fromMap(m)).toList();
        return list.take(maxItemsPerOrg).toList();
      }

      // If items table exists but is empty for this org, auto-migrate existing prices once
      if (!_attemptedMigrations.contains(orgId)) {
        _attemptedMigrations.add(orgId);
        final migrated = await _migrateExistingPricesToItemsTable(orgId);
        if (migrated.isNotEmpty) {
          final res = activeOnly ? migrated.where((it) => it.isActive).toList() : migrated;
          return res.take(maxItemsPerOrg).toList();
        }
      }
    } catch (e) {
      debugPrint('Note: items table query returned: $e');
    }

    // 2. Query fallback from organization metadata (company_line_5)

    // Check company_line_5 for custom items JSON
    try {
      final orgDoc = await Supabase.instance.client
          .from('organizations')
          .select('company_line_5')
          .eq('id', orgId)
          .maybeSingle();

      if (orgDoc != null && orgDoc['company_line_5'] != null) {
        String raw = orgDoc['company_line_5'].toString().trim();
        if (raw.startsWith('{')) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          if (decoded['custom_items'] is List) {
            final rawItems = decoded['custom_items'] as List;
            if (rawItems.isNotEmpty) {
              var list = rawItems
                  .map((m) => CustomItem.fromMap(Map<String, dynamic>.from(m as Map)));
              if (activeOnly) {
                list = list.where((it) => it.isActive);
              }
              final result = list.toList();
              if (result.isNotEmpty) {
                return result.take(maxItemsPerOrg).toList();
              }
            }
          }
        }
      }
    } catch (_) {}

    return _getDefaultItems(orgId);
  }

  /// Default baseline items (Slots 1 to 4) mapped to existing legacy prices.
  static List<CustomItem> _getDefaultItems(String orgId, [Map<String, dynamic>? priceDoc]) {
    double f1 = (priceDoc?['fertilizer1Price'] as num?)?.toDouble() ?? 15500.0;
    double f2 = (priceDoc?['fertilizer2Price'] as num?)?.toDouble() ?? 18000.0;
    double t1 = (priceDoc?['teaPacket1Price'] as num?)?.toDouble() ?? 650.0;
    double t2 = (priceDoc?['teaPacket2Price'] as num?)?.toDouble() ?? 0.0;

    return [
      CustomItem(
        id: '${orgId}_slot_1',
        organizationId: orgId,
        slotIndex: 1,
        code: 'F1',
        name: AppStrings.fertilizer1,
        unitPrice: f1,
      ),
      CustomItem(
        id: '${orgId}_slot_2',
        organizationId: orgId,
        slotIndex: 2,
        code: 'F2',
        name: AppStrings.fertilizer2,
        unitPrice: f2,
      ),
      CustomItem(
        id: '${orgId}_slot_3',
        organizationId: orgId,
        slotIndex: 3,
        code: 'T1',
        name: AppStrings.teaPacket1,
        unitPrice: t1,
      ),
      CustomItem(
        id: '${orgId}_slot_4',
        organizationId: orgId,
        slotIndex: 4,
        code: 'T2',
        name: AppStrings.teaPacket2,
        unitPrice: t2,
      ),
    ];
  }

  /// Automatically seeds/migrates existing prices from global_settings into the dedicated items table
  static Future<List<CustomItem>> _migrateExistingPricesToItemsTable(String orgId) async {
    Map<String, dynamic>? priceDoc;
    try {
      priceDoc = await Supabase.instance.client
          .from('global_settings')
          .select()
          .eq('organization_id', orgId)
          .eq('id', 'prices')
          .maybeSingle();
    } catch (_) {}

    final defaultItems = _getDefaultItems(orgId, priceDoc);
    try {
      for (var item in defaultItems) {
        await Supabase.instance.client.from('items').upsert(item.toMap());
      }
    } catch (e) {
      debugPrint('Auto-migration to items table: $e');
    }
    return defaultItems;
  }

  /// Saves or updates an item. Strictly enforces the maximum 8 active items per organization.
  static Future<void> saveItem(CustomItem item) async {
    final orgId = item.organizationId.isNotEmpty
        ? item.organizationId
        : (AppState.currentOrganizationId.value ?? '');
    if (orgId.isEmpty) throw Exception('No active organization ID.');

    final existingActive = await getItems(organizationId: orgId, activeOnly: true);
    final isNewItem = !existingActive.any((it) => it.id == item.id);

    if (isNewItem && existingActive.length >= maxItemsPerOrg) {
      throw Exception(AppStrings.maxItemsReached);
    }

    // Determine slot index if not assigned
    int assignedSlot = item.slotIndex;
    if (assignedSlot < 1 || assignedSlot > maxItemsPerOrg) {
      final usedSlots = existingActive.map((e) => e.slotIndex).toSet();
      for (int i = 1; i <= maxItemsPerOrg; i++) {
        if (!usedSlots.contains(i)) {
          assignedSlot = i;
          break;
        }
      }
    }

    final String itemId = item.id.isNotEmpty
        ? item.id
        : '${orgId}_item_${DateTime.now().millisecondsSinceEpoch}';

    final updatedItem = item.copyWith(
      id: itemId,
      organizationId: orgId,
      slotIndex: assignedSlot,
      isActive: true,
    );

    // 1. Try saving to 'items' table
    bool savedInItemsTable = false;
    try {
      await Supabase.instance.client.from('items').upsert(updatedItem.toMap());
      savedInItemsTable = true;
    } catch (e) {
      debugPrint('items table not yet created or upsert failed: $e');
    }

    // 2. Save in company_line_5 custom_items JSON for robust cross-version compatibility
    try {
      final allExisting = await getItems(organizationId: orgId, activeOnly: false);
      final updatedList = allExisting
          .where((it) => it.id != updatedItem.id && it.slotIndex != updatedItem.slotIndex)
          .toList()
        ..add(updatedItem);
      updatedList.sort((a, b) => a.slotIndex.compareTo(b.slotIndex));

      await _saveItemsToCompanyLine5(orgId, updatedList);
    } catch (e) {
      debugPrint('Failed to update company_line_5 custom_items: $e');
      if (!savedInItemsTable) rethrow;
    }
  }

  /// Safely deactivates an item (soft-delete) to protect historical entries and billing records.
  /// The item record and its historical price/name mapping remain permanently stored in Supabase.
  /// If [permanent] is true, it hard-deletes the row (only used if explicitly requested).
  static Future<void> deleteItem(CustomItem item, {bool permanent = false}) async {
    final orgId = item.organizationId.isNotEmpty
        ? item.organizationId
        : (AppState.currentOrganizationId.value ?? '');
    if (orgId.isEmpty) return;

    if (permanent) {
      // 1. Hard delete from 'items' table
      try {
        await Supabase.instance.client
            .from('items')
            .delete()
            .eq('organization_id', orgId)
            .eq('id', item.id);
      } catch (_) {}

      // 2. Hard delete from company_line_5
      try {
        final existing = await getItems(organizationId: orgId, activeOnly: false);
        final updatedList = existing.where((it) => it.id != item.id && it.slotIndex != item.slotIndex).toList();
        await _saveItemsToCompanyLine5(orgId, updatedList);
      } catch (e) {
        debugPrint('Failed to delete item from company_line_5: $e');
      }
    } else {
      // Soft-delete / deactivate to preserve historical data
      try {
        await Supabase.instance.client
            .from('items')
            .update({'is_active': false})
            .eq('organization_id', orgId)
            .eq('id', item.id);
      } catch (_) {}

      // Soft-delete in company_line_5
      try {
        final existing = await getItems(organizationId: orgId, activeOnly: false);
        final updatedList = existing.map((it) {
          if (it.id == item.id || (it.slotIndex == item.slotIndex && it.code == item.code)) {
            return it.copyWith(isActive: false);
          }
          return it;
        }).toList();
        await _saveItemsToCompanyLine5(orgId, updatedList);
      } catch (e) {
        debugPrint('Failed to deactivate item in company_line_5: $e');
      }
    }
  }

  /// Helper to persist custom items JSON into organizations table metadata
  static Future<void> _saveItemsToCompanyLine5(String orgId, List<CustomItem> items) async {
    final orgDoc = await Supabase.instance.client
        .from('organizations')
        .select('company_line_5')
        .eq('id', orgId)
        .maybeSingle();

    Map<String, dynamic> metadata = {};
    if (orgDoc != null && orgDoc['company_line_5'] != null) {
      String raw = orgDoc['company_line_5'].toString().trim();
      if (raw.startsWith('{')) {
        try {
          metadata = jsonDecode(raw) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    metadata['custom_items'] = items.map((it) => it.toMap()).toList();

    await Supabase.instance.client
        .from('organizations')
        .update({'company_line_5': jsonEncode(metadata)})
        .eq('id', orgId);
  }

  /// Parses items from a daily_entries row, prioritizing `dynamic_items` JSON
  /// and gracefully falling back to legacy 4-column fields without double-counting.
  static ParsedEntryItems parseDailyEntryItems(
    Map<String, dynamic> entry, {
    double f1Price = 0.0,
    double f2Price = 0.0,
    double t1Price = 0.0,
    double t2Price = 0.0,
  }) {
    double f1Q = 0.0, f2Q = 0.0, t1Q = 0.0, t2Q = 0.0;
    double f1A = 0.0, f2A = 0.0, t1A = 0.0, t2A = 0.0;
    double otherA = 0.0, otherQ = 0.0;
    List<Map<String, dynamic>> itemsList = [];

    bool hasDynamic = false;
    dynamic dyn = entry['dynamic_items'];
    if (dyn != null) {
      if (dyn is String) {
        try {
          dyn = jsonDecode(dyn);
        } catch (_) {}
      }
      if (dyn is Map) {
        dyn.forEach((key, val) {
          if (key.toString().startsWith('item_') && val is Map) {
            double q = (val['qty'] as num?)?.toDouble() ??
                (double.tryParse(val['qty']?.toString() ?? '') ?? 0.0);
            if (q > 0) {
              hasDynamic = true;
              int slot = (val['slot'] as num?)?.toInt() ?? 0;
              String code = (val['code'] ?? '').toString();
              String name = (val['name'] ?? key).toString();
              double uPrice = (val['unitPrice'] as num?)?.toDouble() ??
                  (double.tryParse(val['unitPrice']?.toString() ?? '') ?? 0.0);
              double amt = (val['amt'] as num?)?.toDouble() ??
                  (double.tryParse(val['amt']?.toString() ?? '') ?? 0.0);
              if (amt == 0 && uPrice > 0) amt = q * uPrice;

              itemsList.add({
                'id': val['id'],
                'slot': slot,
                'desc': name,
                'code': code,
                'qty': q,
                'uPrice': uPrice,
                'amt': amt,
              });

              if (slot == 1 || code == 'F1') {
                f1Q += q;
                f1A += (amt > 0 ? amt : q * f1Price);
              } else if (slot == 2 || code == 'F2') {
                f2Q += q;
                f2A += (amt > 0 ? amt : q * f2Price);
              } else if (slot == 3 || code == 'T1') {
                t1Q += q;
                t1A += (amt > 0 ? amt : q * t1Price);
              } else if (slot == 4 || code == 'T2') {
                t2Q += q;
                t2A += (amt > 0 ? amt : q * t2Price);
              } else {
                otherQ += q;
                otherA += amt;
              }
            }
          }
        });

        // Check if short keys exist when no item_ map was found
        if (!hasDynamic) {
          double sf1 = (dyn['F1'] as num?)?.toDouble() ?? 0.0;
          double sf2 = (dyn['F2'] as num?)?.toDouble() ?? 0.0;
          double st1 = (dyn['T1'] as num?)?.toDouble() ?? 0.0;
          double st2 = (dyn['T2'] as num?)?.toDouble() ?? 0.0;
          if (sf1 > 0 || sf2 > 0 || st1 > 0 || st2 > 0) {
            hasDynamic = true;
            if (sf1 > 0) {
              f1Q = sf1;
              f1A = sf1 * f1Price;
              itemsList.add({'desc': 'Fert 01', 'code': 'F1', 'slot': 1, 'qty': sf1, 'uPrice': f1Price, 'amt': f1A});
            }
            if (sf2 > 0) {
              f2Q = sf2;
              f2A = sf2 * f2Price;
              itemsList.add({'desc': 'Fert 02', 'code': 'F2', 'slot': 2, 'qty': sf2, 'uPrice': f2Price, 'amt': f2A});
            }
            if (st1 > 0) {
              t1Q = st1;
              t1A = st1 * t1Price;
              itemsList.add({'desc': 'Tea Pkt 01', 'code': 'T1', 'slot': 3, 'qty': st1, 'uPrice': t1Price, 'amt': t1A});
            }
            if (st2 > 0) {
              t2Q = st2;
              t2A = st2 * t2Price;
              itemsList.add({'desc': 'Tea Pkt 02', 'code': 'T2', 'slot': 4, 'qty': st2, 'uPrice': t2Price, 'amt': t2A});
            }
          }
        }
      }
    }

    // Fallback to legacy columns ONLY when dynamic_items had no active items
    if (!hasDynamic) {
      double f1 = (entry['fertilizer1Qty'] as num?)?.toDouble() ??
          (double.tryParse(entry['fertilizer1Qty']?.toString() ?? '') ?? 0.0);
      double f2 = (entry['fertilizer2Qty'] as num?)?.toDouble() ??
          (double.tryParse(entry['fertilizer2Qty']?.toString() ?? '') ?? 0.0);
      double t1 = (entry['teaPacket1Qty'] as num?)?.toDouble() ??
          (double.tryParse(entry['teaPacket1Qty']?.toString() ?? '') ?? 0.0);
      double t2 = (entry['teaPacket2Qty'] as num?)?.toDouble() ??
          (double.tryParse(entry['teaPacket2Qty']?.toString() ?? '') ?? 0.0);

      if (f1 > 0) {
        f1Q = f1;
        f1A = f1 * f1Price;
        itemsList.add({'desc': 'Fert 01', 'code': 'F1', 'slot': 1, 'qty': f1, 'uPrice': f1Price, 'amt': f1A});
      }
      if (f2 > 0) {
        f2Q = f2;
        f2A = f2 * f2Price;
        itemsList.add({'desc': 'Fert 02', 'code': 'F2', 'slot': 2, 'qty': f2, 'uPrice': f2Price, 'amt': f2A});
      }
      if (t1 > 0) {
        t1Q = t1;
        t1A = t1 * t1Price;
        itemsList.add({'desc': 'Tea Pkt 01', 'code': 'T1', 'slot': 3, 'qty': t1, 'uPrice': t1Price, 'amt': t1A});
      }
      if (t2 > 0) {
        t2Q = t2;
        t2A = t2 * t2Price;
        itemsList.add({'desc': 'Tea Pkt 02', 'code': 'T2', 'slot': 4, 'qty': t2, 'uPrice': t2Price, 'amt': t2A});
      }
    }

    return ParsedEntryItems(
      f1Qty: f1Q,
      f2Qty: f2Q,
      t1Qty: t1Q,
      t2Qty: t2Q,
      f1Amt: f1A,
      f2Amt: f2A,
      t1Amt: t1A,
      t2Amt: t2A,
      otherDynamicAmt: otherA,
      otherDynamicQty: otherQ,
      itemsList: itemsList,
    );
  }
}

/// Parsed representations of all dynamic and legacy items for a single daily entry.
class ParsedEntryItems {
  final double f1Qty;
  final double f2Qty;
  final double t1Qty;
  final double t2Qty;
  final double f1Amt;
  final double f2Amt;
  final double t1Amt;
  final double t2Amt;
  final double otherDynamicAmt;
  final double otherDynamicQty;
  final List<Map<String, dynamic>> itemsList;

  ParsedEntryItems({
    required this.f1Qty,
    required this.f2Qty,
    required this.t1Qty,
    required this.t2Qty,
    required this.f1Amt,
    required this.f2Amt,
    required this.t1Amt,
    required this.t2Amt,
    required this.otherDynamicAmt,
    this.otherDynamicQty = 0.0,
    required this.itemsList,
  });

  double get totalFertilizerQty => f1Qty + f2Qty;
  double get totalTeaPacketQty => t1Qty + t2Qty;
  double get totalItemsQty => f1Qty + f2Qty + t1Qty + t2Qty + otherDynamicQty;
  double get totalItemsAmt => f1Amt + f2Amt + t1Amt + t2Amt + otherDynamicAmt;
  bool get hasAnyItems =>
      (f1Qty > 0 || f2Qty > 0 || t1Qty > 0 || t2Qty > 0 || itemsList.isNotEmpty);
  bool get hasFertilizer => (f1Qty > 0 || f2Qty > 0);
  bool get hasTeaPacket => (t1Qty > 0 || t2Qty > 0);
}
