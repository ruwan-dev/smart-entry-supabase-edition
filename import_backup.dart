import 'dart:convert';
import 'dart:io';
import 'package:supabase/supabase.dart';

Future<void> main() async {
  print('Initializing Supabase for Data Import...');
  final client = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );

  final file = File('smart_entry_backup_1789025634701.json');
  if (!await file.exists()) {
    print('Backup file not found!');
    exit(1);
  }

  print('Reading JSON backup...');
  final jsonString = await file.readAsString();
  final data = jsonDecode(jsonString) as Map<String, dynamic>;

  // 1. Import Customers
  if (data.containsKey('Customers')) {
    print('Importing Customers...');
    List<Map<String, dynamic>> customers = [];
    for (var doc in data['Customers']) {
      customers.add({
        'id': doc['documentId'],
        'name': doc['name'],
        'refNumber': doc['refNumber'],
        'phone': doc['phone'],
        'address': doc['address'],
        'registeredAt': doc['registeredAt'],
      });
    }
    // Batch insert
    for (int i = 0; i < customers.length; i += 500) {
      final batch = customers.skip(i).take(500).toList();
      await client.from('customers').insert(batch);
    }
    print('✓ Customers imported (${customers.length})');
  }

  // 2. Import GlobalSettings
  if (data.containsKey('GlobalSettings')) {
    print('Importing Global Settings...');
    List<Map<String, dynamic>> settings = [];
    for (var doc in data['GlobalSettings']) {
      settings.add({
        'id': doc['documentId'],
        'password': doc['password'],
        'fertilizer1Price': doc['fertilizer1Price'],
        'fertilizer2Price': doc['fertilizer2Price'],
        'teaPacket1Price': doc['teaPacket1Price'],
        'teaPacket2Price': doc['teaPacket2Price'],
      });
    }
    await client.from('global_settings').insert(settings);
    print('✓ Global Settings imported');
  }

  // 3. Import MonthlyRates
  if (data.containsKey('MonthlyRates')) {
    print('Importing Monthly Rates...');
    List<Map<String, dynamic>> rates = [];
    for (var doc in data['MonthlyRates']) {
      rates.add({
        'id': doc['documentId'],
        'teaRate': doc['teaRate'],
        'transportRate': doc['transportRate'],
        'month': doc['month'],
        'year': doc['year'],
        'sortValue': doc['sortValue'],
      });
    }
    await client.from('monthly_rates').insert(rates);
    print('✓ Monthly Rates imported (${rates.length})');
  }

  // 4. Import DailyEntries
  if (data.containsKey('DailyEntries')) {
    print('Importing Daily Entries... (This might take a moment)');
    List<Map<String, dynamic>> entries = [];
    for (var doc in data['DailyEntries']) {
      entries.add({
        'id': doc['documentId'],
        'customerId': doc['customerId'],
        'customerName': doc['customerName'],
        'date': doc['date'],
        'timestamp': doc['timestamp'],
        'grossWeight': doc['grossWeight'],
        'deductions': doc['deductions'],
        'netWeight': doc['netWeight'],
        'advanceAmount': doc['advanceAmount'],
        'fertilizer1Qty': doc['fertilizer1Qty'],
        'fertilizer2Qty': doc['fertilizer2Qty'],
        'teaPacket1Qty': doc['teaPacket1Qty'],
        'teaPacket2Qty': doc['teaPacket2Qty'],
        'createdAt': doc['createdAt'],
      });
    }
    
    // Batch insert 500 at a time to avoid payload limits
    for (int i = 0; i < entries.length; i += 500) {
      final batch = entries.skip(i).take(500).toList();
      await client.from('daily_entries').insert(batch);
      print('  -> Inserted ${i + batch.length} / ${entries.length}');
    }
    print('✓ Daily Entries imported (${entries.length})');
  }

  // FinalizedBills and MonthlySummaries usually don't need backup restoration if they are empty or we can just restore them if they exist in JSON.
  // We'll skip them if they aren't in this backup.

  print('🎉 All data successfully restored to Supabase!');
  exit(0);
}
