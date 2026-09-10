import 'package:supabase_flutter/supabase_flutter.dart';

class CreditLimitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // පසුගිය මාස 3ක සාමාන්‍ය Net Weight දළු ප්‍රමාණය ලබා ගැනීම
  Future<double> getAverageTeaLeaves(String customerId) async {
    try {
      // අද සිට දින 90 කට පෙර දිනය
      DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

      var snapshot = await _supabase
          .from('daily_entries') 
          .select('netWeight')
          .eq('customerId', customerId)
          .gte('timestamp', threeMonthsAgo.toIso8601String());

      if (snapshot.isEmpty) {
        return 0.0; // දත්ත නොමැති නම් 0 ක් return කරයි
      }

      double totalNetWeight = 0.0;

      for (var data in snapshot) {
        totalNetWeight += (data['netWeight'] ?? 0).toDouble(); 
      }

      // මාස 3 ක සාමාන්‍යය සෙවීමට 3 න් බෙදීම
      double monthlyAverage = totalNetWeight / 3;
      return monthlyAverage;

    } catch (e) {
      throw Exception('දත්ත ලබා ගැනීමේදී දෝෂයක් මතු විය: $e');
    }
  }
}