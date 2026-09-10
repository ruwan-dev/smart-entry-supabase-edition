import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print("STARTING_BACKUP...");
  try {
    Map<String, dynamic> fullBackupData = {};
    List<String> collections = ['GlobalSettings', 'Customers', 'DailyEntries', 'MonthlyRates', 'MonthlySummaries'];
    
    for (String col in collections) {
      print("Fetching \$col...");
      var snapshot = await FirebaseFirestore.instance.collection(col).get();
      fullBackupData[col] = snapshot.docs.map((doc) {
        var data = doc.data();
        data['__id'] = doc.id;
        return _sanitizeDataForJson(data);
      }).toList();
    }

    String jsonString = const JsonEncoder.withIndent('  ').convert(fullBackupData);
    File file = File('C:\\Users\\RuwanPathirana\\SmartEntry\\firebase_backup.json');
    await file.writeAsString(jsonString);
    print("BACKUP_SUCCESS: \${file.path}");
  } catch (e) {
    print("BACKUP_ERROR: \$e");
  }
  exit(0);
}

dynamic _sanitizeDataForJson(dynamic data) {
  if (data is Timestamp) {
    return data.toDate().toIso8601String();
  } else if (data is Map) {
    Map<String, dynamic> newMap = {};
    data.forEach((key, value) {
      newMap[key.toString()] = _sanitizeDataForJson(value);
    });
    return newMap;
  } else if (data is List) {
    return data.map((item) => _sanitizeDataForJson(item)).toList();
  }
  return data;
}
