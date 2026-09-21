import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final client = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );

  try {
    final res = await client.from('customers').select('organization_id').notNull('organization_id').limit(1);
    if (res.isNotEmpty) {
      print('Found organization_id: ${res.first['organization_id']}');
    } else {
      print('No organization_id found in customers table.');
      
      // Let's check daily_entries just in case
      final entriesRes = await client.from('daily_entries').select('organization_id').notNull('organization_id').limit(1);
      if (entriesRes.isNotEmpty) {
         print('Found organization_id in daily_entries: ${entriesRes.first['organization_id']}');
      } else {
         print('No organization_id found in daily_entries either.');
      }
    }
  } catch (e) {
    print('Error: $e');
  }
  exit(0);
}
