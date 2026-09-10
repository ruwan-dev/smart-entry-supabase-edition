import 'package:flutter/material.dart';
import '../../services/credit_limit_service.dart';

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
  
  // සාමාන්‍ය තේ දළු කිලෝවක මිල (මෙහි ඔබගේ වර්තමාන දළු මිල යොදන්න)
  final double _currentTeaRate = 200.0; 
  
  // Default Deduction Percentage එක 40%
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

  // උපරිම ණය සීමාව ගණනය කරන Core Logic එක
  double get _calculatedCreditLimit {
    double estimatedMonthlyIncome = _averageLeaves * _currentTeaRate;
    double monthlyDeductionCapacity = estimatedMonthlyIncome * (_deductionPercentage / 100);
    // මාස 12 කින් ආවරණය කරගත හැකි උපරිම ණය සීමාව
    return monthlyDeductionCapacity * 12; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Limit Calculator'),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
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
                
                // දත්ත පෙන්වීම
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow('මාස 3 ක සාමාන්‍ය (Net Weight):', '${_averageLeaves.toStringAsFixed(2)} Kg'),
                        const Divider(height: 20),
                        _buildInfoRow('කිලෝ 1 ක වර්තමාන මිල:', 'Rs. ${_currentTeaRate.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 35),

                // Deduction Percentage Slider එක
                const Text(
                  'ණය වෙනුවෙන් කපාගන්නා ප්‍රතිශතය',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

                // අවසාන ප්‍රතිඵලය
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
                      const Text(
                        'ලබා දිය හැකි උපරිම ණය මුදල',
                        style: TextStyle(fontSize: 18, color: Colors.red, fontWeight: FontWeight.w600),
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
                        '(මාස 12 කින් අයකර ගැනීමේ පදනම මත)',
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