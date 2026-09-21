import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  print('Initializing Supabase...');
  final client = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );

  try {
    // 1. Get the organization_id from app_users
    final userRes = await client.from('app_users').select('organization_id').limit(1);
    if (userRes.isEmpty) {
      print('No organization_id found in app_users!');
      exit(1);
    }
    
    final orgId = userRes.first['organization_id'].toString();
    print('Found Organization ID: $orgId');

    final tables = [
      'customers',
      'global_settings',
      'monthly_rates',
      'daily_entries',
      'monthly_summaries',
      'finalized_bills'
    ];

    for (var table in tables) {
      print('Updating $table...');
      // Update all rows where organization_id is null or different
      await client.from(table).update({'organization_id': orgId}).neq('id', 'dummy'); 
      print('✓ $table updated with orgId: $orgId');
    }

    print('🎉 All tables successfully updated with organization_id: $orgId');
  } catch (e) {
    print('Error updating data: $e');
  }

  exit(0);
}
