import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:smart_entry/core/entries/daily_entry_form_screen.dart'; 

class DailyEntriesScreen extends StatefulWidget {
  final String? initialCustomerId;
  final String? initialRefNumber;

  const DailyEntriesScreen({super.key, this.initialCustomerId, this.initialRefNumber});

  @override
  State<DailyEntriesScreen> createState() => _DailyEntriesScreenState();
}

class _DailyEntriesScreenState extends State<DailyEntriesScreen> {
  DateTime _selectedMonth = DateTime.now();
  String? _selectedCustomerId;
  final TextEditingController _refController = TextEditingController();
  List<Map<String, dynamic>> _allCustomers = []; 

  @override
  void initState() {
    super.initState();
    if (widget.initialCustomerId != null) {
      _selectedCustomerId = widget.initialCustomerId;
      _refController.text = widget.initialRefNumber ?? '';
    }
  }

  @override
  void dispose() {
    _refController.dispose();
    super.dispose();
  }

  void _changeMonth(int monthsToAdd) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + monthsToAdd, 1);
    });
  }

  void _onDateTapped(int day) {
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('කරුණාකර පාරිභෝගිකයෙකු තෝරන්න 👤'), backgroundColor: Colors.orange),
      );
      return;
    }

    var customer = _allCustomers.firstWhere((c) => c['id'] == _selectedCustomerId);
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DailyEntryFormScreen(
          selectedDate: DateTime(_selectedMonth.year, _selectedMonth.month, day),
          customerId: _selectedCustomerId!,
          customerName: customer['name'],
          refNumber: customer['refNumber'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String monthName = DateFormat('MMMM yyyy').format(_selectedMonth);
    String monthPrefix = DateFormat('yyyy-MM').format(_selectedMonth);

    // අද දවස ලබා ගැනීම (වෙලාව නැතිව, දවස පමණක් සලකා බැලීම සඳහා)
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      appBar: AppBar(title: const Text('දෛනික සටහන්')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.white,
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client.from('customers').stream(primaryKey: ['id']).order('name'),
              builder: (context, snapshot) {
                if (snapshot.hasData) _allCustomers = snapshot.data!;

                return Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _refController,
                        decoration: const InputDecoration(labelText: 'අංකය', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          final match = _allCustomers.where((c) => c['refNumber'] == value.trim()).toList();
                          setState(() {
                            _selectedCustomerId = match.isNotEmpty ? match.first['id'] : null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'නම', border: OutlineInputBorder()),
                        isExpanded: true,
                        value: _selectedCustomerId,
                        items: _allCustomers.map((doc) {
                          return DropdownMenuItem<String>(value: doc['id'] as String, child: Text(doc['name'] as String));
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCustomerId = val;
                            final customer = _allCustomers.firstWhere((c) => c['id'] == val);
                            _refController.text = customer['refNumber'];
                          });
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: () => _changeMonth(-1)),
                Text(monthName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: () => _changeMonth(1)),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: Supabase.instance.client
                  .from('daily_entries')
                  .stream(primaryKey: ['id'])
                  .gte('date', '$monthPrefix-01')
                  .lte('date', '$monthPrefix-31'),
              builder: (context, snapshot) {
                
                Map<int, Map<String, double>> totals = {};
                
                if (snapshot.hasData && _selectedCustomerId != null) {
                  for (var doc in snapshot.data!) {
                    if (doc['customerId'] == _selectedCustomerId) {
                      try {
                        int day = int.parse(doc['date'].split('-')[2]);
                        
                        if (!totals.containsKey(day)) {
                          totals[day] = {'weight': 0.0, 'advance': 0.0, 'fert': 0.0, 'tea': 0.0};
                        }
                        
                        totals[day]!['weight'] = totals[day]!['weight']! + (doc['netWeight'] ?? 0).toDouble();
                        totals[day]!['advance'] = totals[day]!['advance']! + (doc['advanceAmount'] ?? 0).toDouble();
                        
                        double f1 = (doc['fertilizer1Qty'] ?? 0).toDouble();
                        double f2 = (doc['fertilizer2Qty'] ?? 0).toDouble();
                        totals[day]!['fert'] = totals[day]!['fert']! + f1 + f2;
                        
                        double t1 = (doc['teaPacket1Qty'] ?? 0).toDouble();
                        double t2 = (doc['teaPacket2Qty'] ?? 0).toDouble();
                        totals[day]!['tea'] = totals[day]!['tea']! + t1 + t2;
                        
                      } catch (e) { }
                    }
                  }
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    double crossAxisSpacing = 4.0;
                    
                    int crossAxisCount = 7;
                    if (constraints.maxWidth >= 1200) {
                      crossAxisCount = 14;
                    } else if (constraints.maxWidth >= 800) {
                      crossAxisCount = 10;
                    } else if (constraints.maxWidth >= 600) {
                      crossAxisCount = 7;
                    } else if (constraints.maxWidth >= 400) {
                      crossAxisCount = 5;
                    } else {
                      crossAxisCount = 4;
                    }

                    double paddingHorizontal = 16.0; 
                    
                    double totalAvailableWidth = constraints.maxWidth - paddingHorizontal - (crossAxisSpacing * (crossAxisCount - 1));
                    double itemWidth = totalAvailableWidth / crossAxisCount;
                    
                    double itemHeight = 130.0; 
                    double responsiveAspectRatio = itemWidth / itemHeight;

                    return GridView.builder(
                      padding: const EdgeInsets.all(8.0),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount, 
                        crossAxisSpacing: crossAxisSpacing, 
                        mainAxisSpacing: 6, 
                        childAspectRatio: responsiveAspectRatio, 
                      ),
                      itemCount: DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day,
                      itemBuilder: (context, index) {
                        int day = index + 1;
                        
                        var dayData = totals[day] ?? {'weight': 0.0, 'advance': 0.0, 'fert': 0.0, 'tea': 0.0};
                        double weight = dayData['weight']!;
                        double advance = dayData['advance']!;
                        double fert = dayData['fert']!;
                        double tea = dayData['tea']!;
                        
                        bool hasData = weight > 0 || advance > 0 || fert > 0 || tea > 0;

                        DateTime cellDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                        bool isFuture = cellDate.isAfter(today);

                        return InkWell(
                          onTap: isFuture ? null : () => _onDateTapped(day),
                          child: Container(
                            padding: const EdgeInsets.all(2.0),
                            decoration: BoxDecoration(
                              color: isFuture 
                                  ? Colors.grey.shade200 
                                  : (hasData ? Theme.of(context).primaryColor.withValues(alpha: 0.08) : Colors.white),
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: isFuture 
                                    ? Colors.grey.shade300 
                                    : (hasData ? Theme.of(context).primaryColor : Colors.grey.shade300)
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                const SizedBox(height: 2),
                                Text(
                                  day.toString(), 
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold, 
                                    color: isFuture 
                                        ? Colors.grey.shade400 
                                        : (hasData ? Colors.black87 : Colors.grey)
                                  )
                                ),
                                const Spacer(), 
                                
                                if (weight > 0) 
                                  _buildAlignedRow(Icons.eco, Colors.green, weight.toStringAsFixed(1)),
                                if (advance > 0) 
                                  _buildAlignedRow(Icons.money, Colors.blue, NumberFormat.compact().format(advance)),
                                if (fert > 0) 
                                  _buildAlignedRow(Icons.eco, const Color.fromARGB(255, 60, 6, 6), fert.toStringAsFixed(0)), 
                                if (tea > 0) 
                                  _buildAlignedRow(Icons.local_cafe, Colors.orange, tea.toStringAsFixed(0)),
                                  
                                const SizedBox(height: 2),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlignedRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Icon(icon, size: 12, color: color),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            flex: 6,
            child: Text(
              text,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
              textAlign: TextAlign.left,
              overflow: TextOverflow.ellipsis, 
            ),
          ),
        ],
      ),
    );
  }
}