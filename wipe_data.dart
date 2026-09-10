import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  print('Initializing Supabase...');
  final client = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );

  try {
    print('Deleting finalized_bills...');
    await client.from('finalized_bills').delete().neq('id', 'dummy_value_to_delete_all');
    
    print('Deleting monthly_summaries...');
    await client.from('monthly_summaries').delete().neq('id', 'dummy_value_to_delete_all');

    print('Deleting daily_entries...');
    await client.from('daily_entries').delete().neq('id', 'dummy_value_to_delete_all');

    print('Deleting monthly_rates...');
    await client.from('monthly_rates').delete().neq('id', 'dummy_value_to_delete_all');

    print('Deleting global_settings...');
    await client.from('global_settings').delete().neq('id', 'dummy_value_to_delete_all');

    print('Deleting customers...');
    await client.from('customers').delete().neq('id', 'dummy_value_to_delete_all');

    print('All data wiped successfully!');
  } catch (e) {
    print('Error wiping data: $e');
  }

  exit(0);
}
