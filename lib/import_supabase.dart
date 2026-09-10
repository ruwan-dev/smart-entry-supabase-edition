import 'dart:convert';
import 'dart:io';

const String supabaseUrl = 'https://etlxrdxldtobffzficxu.supabase.co';
const String supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV0bHhyZHhsZHRvYmZmemZpY3h1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMDU4MjAsImV4cCI6MjEwNDU4MTgyMH0.ZphFjMlc9-RpJ0Pr7zdCYPSVgl1FK0plC6JwPC9IwIY';

final Map<String, List<String>> allowedColumns = {
  'customers': ['id', 'refNumber', 'name', 'address', 'phone', 'registeredAt'],
  'daily_entries': ['id', 'customerId', 'customerName', 'date', 'timestamp', 'grossWeight', 'deductions', 'netWeight', 'advanceAmount', 'fertilizer1Qty', 'fertilizer2Qty', 'teaPacket1Qty', 'teaPacket2Qty', 'createdAt', 'updatedAt'],
  'monthly_rates': ['id', 'teaRate'],
  'monthly_summaries': ['id', 'totalWeight', 'totalGross', 'totalAdvance', 'totalTransport', 'totalF1Amt', 'totalF2Amt', 'totalT1Amt', 'totalT2Amt', 'totalNegativeNet', 'totalPositiveNet', 'totalNet', 'totalF1Qty', 'totalF2Qty', 'totalT1Qty', 'totalT2Qty', 'totalFertilizer', 'totalTeaPacket', 'finalizedAt'],
  'global_settings': ['id', 'password', 'fertilizer1Price', 'fertilizer2Price', 'teaPacket1Price', 'teaPacket2Price']
};

Future<void> main() async {
  File file = File('C:\\Users\\RuwanPathirana\\SmartEntry\\firebase_backup.json');
  if (!await file.exists()) {
    print('Backup file not found.');
    exit(1);
  }
  
  String content = await file.readAsString();
  Map<String, dynamic> backup = jsonDecode(content);
  
  await uploadTable('global_settings', backup['GlobalSettings'] ?? []);
  await uploadTable('customers', backup['Customers'] ?? []);
  await uploadTable('daily_entries', backup['DailyEntries'] ?? []);
  await uploadTable('monthly_rates', backup['MonthlyRates'] ?? []);
  await uploadTable('monthly_summaries', backup['MonthlySummaries'] ?? []);
  
  print('IMPORT COMPLETE');
  exit(0);
}

Future<void> uploadTable(String tableName, List<dynamic> records) async {
  if (records.isEmpty) {
    print('No records for $tableName');
    return;
  }
  
  print('Uploading $tableName (${records.length} records)...');
  
  List<Map<String, dynamic>> rawPayload = [];
  List<String> validCols = allowedColumns[tableName] ?? [];
  
  for (var rec in records) {
    Map<String, dynamic> row = Map<String, dynamic>.from(rec);
    if (row.containsKey('__id')) {
      row['id'] = row['__id'];
      row.remove('__id');
    }
    
    Map<String, dynamic> filteredRow = {};
    for (String col in validCols) {
      filteredRow[col] = row.containsKey(col) ? row[col] : null;
    }
    rawPayload.add(filteredRow);
  }
  
  int chunkSize = 500; 
  for (int i = 0; i < rawPayload.length; i += chunkSize) {
    var chunk = rawPayload.sublist(i, i + chunkSize > rawPayload.length ? rawPayload.length : i + chunkSize);
    
    HttpClient client = HttpClient();
    HttpClientRequest req = await client.postUrl(Uri.parse('$supabaseUrl/rest/v1/$tableName'));
    req.headers.set('apikey', supabaseKey);
    req.headers.set('Authorization', 'Bearer $supabaseKey');
    req.headers.set('Content-Type', 'application/json');
    req.headers.set('Prefer', 'resolution=merge-duplicates');
    
    req.add(utf8.encode(jsonEncode(chunk)));
    HttpClientResponse res = await req.close();
    
    String resBody = await res.transform(utf8.decoder).join();
    if (res.statusCode >= 200 && res.statusCode < 300) {
      print('Chunk $i inserted successfully into $tableName.');
    } else {
      print('Error inserting chunk $i into $tableName: ${res.statusCode} \n$resBody');
    }
    client.close();
  }
}
