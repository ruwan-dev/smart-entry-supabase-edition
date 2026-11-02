import 'package:supabase/supabase.dart';
import 'dart:io';

Future<void> main() async {
  final client = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );

  final orgId = '11111111-1111-1111-1111-111111111111';
  final sample = await client
      .from('daily_entries')
      .select('id, date, customerName, fertilizer1Qty, fertilizer2Qty, teaPacket1Qty, teaPacket2Qty, dynamic_items')
      .eq('organization_id', orgId)
      .gt('fertilizer1Qty', 0)
      .limit(1)
      .single();

  print('\n=== SAMPLE MIGRATED ROW FOR ORG 1111 ===');
  sample.forEach((k, v) => print('$k: $v'));
  exit(0);
}
