import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://etlxrdxldtobffzficxu.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY',
  );
  try {
    final res = await supabase.from('customers').select().limit(1);
    print(res);
  } catch (e) {
    print(e);
  }
}
