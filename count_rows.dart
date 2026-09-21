import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  print('Initializing Supabase...');
  final client = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );

  final tables = [
    'customers',
    'global_settings',
    'monthly_rates',
    'daily_entries',
    'monthly_summaries',
    'finalized_bills'
  ];

  try {
    for (var table in tables) {
      final res = await client.from(table).select('id').count(CountOption.exact);
      print('$table: ${res.count} rows');
    }
  } catch (e) {
    try {
        for (var table in tables) {
          final res = await client.from(table).select('id');
          print('$table: ${res.length} rows');
        }
    } catch (e2) {
       print('Error counting data fallback: $e2');
    }
  }

  exit(0);
}
