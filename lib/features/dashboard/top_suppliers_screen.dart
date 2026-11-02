import 'package:smart_entry/core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TopSuppliersScreen extends StatelessWidget {
  final List<Map<String, dynamic>> allSuppliers;

  const TopSuppliersScreen({super.key, required this.allSuppliers});

  @override
  Widget build(BuildContext context) {
    final weightF = NumberFormat('#,##0.##', 'en_US');
    final Color primaryAppColor = const Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(AppStrings.allSuppliers, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
      ),
      body: allSuppliers.isEmpty
          ? Center(child: Text(AppStrings.noDataFound, style: const TextStyle(color: Colors.grey)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: allSuppliers.length,
              itemBuilder: (context, index) {
                var supplier = allSuppliers[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))
                    ]
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          (index + 1).toString(),
                          style: TextStyle(color: primaryAppColor, fontWeight: FontWeight.w800)
                        )
                      )
                    ),
                    title: Text(
                      supplier['name'] ?? 'Unknown',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF374151))
                    ),
                    trailing: Text(
                      '${weightF.format(supplier['weight'])} Kg',
                      style: TextStyle(color: primaryAppColor, fontWeight: FontWeight.w800, fontSize: 14)
                    )
                  ),
                );
              },
            ),
    );
  }
}
