import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/app_state.dart';

class CreditLimitService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<double> getAverageTeaLeaves(String customerId) async {
    try {
      DateTime threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));

      var snapshot = await _supabase
          .from('daily_entries') 
          .select('netWeight').eq('organization_id', AppState.currentOrganizationId.value ?? '')
          .eq('customerId', customerId)
          .gte('timestamp', threeMonthsAgo.toIso8601String());

      if (snapshot.isEmpty) {
        return 0.0;
      }

      double totalNetWeight = 0.0;

      for (var data in snapshot) {
        totalNetWeight += (data['netWeight'] ?? 0).toDouble(); 
      }

      double monthlyAverage = totalNetWeight / 3;
      return monthlyAverage;

    } catch (e) {
      throw Exception('Failed to fetch data: $e');
    }
  }
}