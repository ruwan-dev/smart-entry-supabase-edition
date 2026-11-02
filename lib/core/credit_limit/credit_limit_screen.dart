import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/skeleton_box.dart';
import '../../services/credit_limit_service.dart';
import 'package:smart_entry/core/localization/app_strings.dart';

class CreditLimitScreen extends StatefulWidget {
  final String customerId;
  final String customerName;

  const CreditLimitScreen({
    super.key, 
    required this.customerId, 
    required this.customerName,
  });

  @override
  State<CreditLimitScreen> createState() => _CreditLimitScreenState();
}

class _CreditLimitScreenState extends State<CreditLimitScreen> {
  final CreditLimitService _creditLimitService = CreditLimitService();
  
  bool _isLoading = true;
  double _averageLeaves = 0.0;
  
  final double _currentTeaRate = 200.0; 
  
  double _deductionPercentage = 40.0; 

  @override
  void initState() {
    super.initState();
    _fetchAverageLeaves();
  }

  Future<void> _fetchAverageLeaves() async {
    try {
      double avg = await _creditLimitService.getAverageTeaLeaves(widget.customerId);
      setState(() {
        _averageLeaves = avg;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  double get _calculatedCreditLimit {
    double estimatedMonthlyIncome = _averageLeaves * _currentTeaRate;
    double monthlyDeductionCapacity = estimatedMonthlyIncome * (_deductionPercentage / 100);
    return monthlyDeductionCapacity * 12; 
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              const SkeletonBox(width: 40, height: 40, shape: BoxShape.circle),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SkeletonBox(width: 150, height: 16),
                    SizedBox(height: 8),
                    SkeletonBox(width: 100, height: 12),
                  ],
                ),
              ),
              const SkeletonBox(width: 60, height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Limit Calculator'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading 
        ? _buildSkeleton()
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customerName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(AppStrings.isSinhala ? 'මාස 3 ක සාමාන්‍ය:' : '3-Month Average:', '${_averageLeaves.toStringAsFixed(2)} Kg'),
                        const Divider(height: 20),
                        _buildInfoRow(AppStrings.isSinhala ? 'කිලෝ 1 ක වර්තමාන මිල:' : 'Current Rate (1kg):', 'Rs. ${_currentTeaRate.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 35),

                Text(
                  AppStrings.isSinhala ? 'ණය වෙනුවෙන් කපාගන්නා ප්‍රතිශතය' : 'Loan Deduction Percentage',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        value: _deductionPercentage,
                        min: 10,
                        max: 100,
                        divisions: 18,
                        activeColor: Colors.teal,
                        label: '${_deductionPercentage.round()}%',
                        onChanged: (value) {
                          setState(() {
                            _deductionPercentage = value;
                          });
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${_deductionPercentage.round()}%',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.red.shade300, width: 2),
                  ),
                  child: Column(
                    children: [
                      Text(
                        AppStrings.maxCreditLimit,
                        style: const TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        'Rs. ${_calculatedCreditLimit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 34, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.red
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        AppStrings.basedOn12Months,
                        style: TextStyle(fontSize: 13, color: Colors.red.shade300),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}