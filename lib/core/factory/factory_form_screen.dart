import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_state.dart';
import 'add_factory_screen.dart';
import 'package:smart_entry/core/factory/factory_ledger_screen.dart' as smart_entry_ledger;
import 'package:smart_entry/core/factory/factory_report_screen.dart';
import 'package:smart_entry/core/widgets/skeleton_box.dart';
import 'widgets/all_factories_summary_widget.dart';
import '../localization/app_strings.dart';
import '../localization/app_language.dart';

class FactoryFormScreen extends StatefulWidget {
  const FactoryFormScreen({super.key});

  @override
  State<FactoryFormScreen> createState() => _FactoryFormScreenState();
}

class _FactoryFormScreenState extends State<FactoryFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  String _searchQuery = '';
  int _currentPage = 0;
  final int _itemsPerPage = 5; 

  final Color _primaryColor = const Color(0xFF06B6D4);
  final Color _backgroundColor = const Color(0xFFF9FAFC);
  final Color _cardColor = Colors.white;
  final Color _textColorPrimary = const Color(0xFF1E293B);
  final Color _textColorSecondary = const Color(0xFF64748B);
  final Color _borderColor = const Color(0xFFE2E8F0);

  final Color _statusGreenBg = const Color(0xFFF0FDF4); 
  final Color _statusGreenText = const Color(0xFF4ADE80); 
  final Color _tagCyanBg = const Color(0xFFECFEFF); 
  final Color _tagCyanText = const Color(0xFF22D3EE); 

  List<Map<String, dynamic>>? _cachedFactories;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    AppLanguageService.currentLanguage.addListener(_onLanguageChanged);
    AppState.refreshTrigger.addListener(_fetchFactories);
    AppState.currentOrganizationId.addListener(_onOrgChanged);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() => _selectedTabIndex = _tabController.index);
      }
    });
    _fetchFactories();
  }

  void _onOrgChanged() {
    if (mounted) {
      setState(() {
        _cachedFactories = null;
        _currentPage = 0;
      });
      _fetchFactories();
    }
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AppLanguageService.currentLanguage.removeListener(_onLanguageChanged);
    AppState.refreshTrigger.removeListener(_fetchFactories);
    AppState.currentOrganizationId.removeListener(_onOrgChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchFactories() async {
    final orgId = AppState.currentOrganizationId.value ?? '';
    if (orgId.isEmpty) {
      if (mounted) {
        setState(() {
          _cachedFactories = [];
          _errorMessage = null;
        });
      }
      return;
    }
    try {
      final orgId = AppState.currentOrganizationId.value ?? '';

      final response = await Supabase.instance.client
          .from('factories')
          .select()
          .eq('organization_id', orgId)
          .order('name');
          
      if (mounted) {
        setState(() {
          _cachedFactories = List<Map<String, dynamic>>.from(response);
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _deleteFactory(String docId, String name) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.deleteFactoryConfirm),
        content: Text(AppStrings.deleteFactoryPrompt(name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.no),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(AppStrings.yesDelete),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final orgId = AppState.currentOrganizationId.value ?? '';

      // Delete all related factory data to prevent orphaned allocations and rates
      await Supabase.instance.client
          .from('factory_entries')
          .delete()
          .eq('organization_id', orgId)
          .eq('factoryId', docId);

      await Supabase.instance.client
          .from('factory_monthly_rates')
          .delete()
          .eq('organization_id', orgId)
          .eq('factoryId', docId);

      await Supabase.instance.client
          .from('factory_finalized_bills')
          .delete()
          .eq('organization_id', orgId)
          .eq('factoryId', docId);

      await Supabase.instance.client
          .from('factory_activity_logs')
          .delete()
          .eq('organization_id', orgId)
          .eq('factory_id', docId);

      await Supabase.instance.client
          .from('factories')
          .delete()
          .eq('organization_id', orgId)
          .eq('id', docId);

      if (mounted) {
        Navigator.pop(context);
        AppState.triggerRefresh();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.factoryDeleted), backgroundColor: Colors.green),
        );
        _fetchFactories();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppStrings.errorPrefix}$e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildSkeletonItem() {
    return Container(
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween, 
            children: const [SkeletonBox(width: 80, height: 24, borderRadius: 4), SkeletonBox(width: 100, height: 24, borderRadius: 4)]
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: 150, height: 16),
        ],
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildSkeletonItem(),
    );
  }

  Widget _buildResponsiveFactoryItem(String docId, Map<String, dynamic> data) {
    return Container(
      decoration: BoxDecoration(color: _cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: _borderColor)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 8, runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _statusGreenBg, borderRadius: BorderRadius.circular(4), border: Border.all(color: _statusGreenText.withValues(alpha: 0.2))),
                child: Text('${AppStrings.refPrefix}${data['refNumber'] ?? ''}', style: TextStyle(color: _statusGreenText, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: _tagCyanBg, borderRadius: BorderRadius.circular(4)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.phone, size: 12, color: _tagCyanText), const SizedBox(width: 4),
                    Text(data['phone'] ?? '', style: TextStyle(fontSize: 12, color: _tagCyanText, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(data['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _textColorPrimary)),
          if ((data['address'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(data['address'], style: TextStyle(color: _textColorSecondary, fontSize: 13)),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => smart_entry_ledger.FactoryLedgerScreen(
                            factoryId: docId,
                            factoryName: data['name'] ?? '',
                            refNumber: data['refNumber'] ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.settings, size: 20),
                    label: Text(AppStrings.settings, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: _primaryColor,
                      backgroundColor: _primaryColor.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FactoryReportScreen(
                            factoryId: docId,
                            factoryName: data['name'] ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long, size: 20),
                    label: Text(AppStrings.report, style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal,
                      backgroundColor: Colors.teal.withValues(alpha: 0.1),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteFactory(docId, data['name'] ?? ''),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.factoryManagement,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _textColorPrimary,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryColor,
          unselectedLabelColor: _textColorSecondary,
          indicatorColor: _primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.business, size: 18),
              text: AppStrings.factoryDirectory,
            ),
            Tab(
              icon: const Icon(Icons.analytics, size: 18),
              text: AppStrings.combinedSummary,
            ),
          ],
        ),
      ),
      floatingActionButton: (MediaQuery.of(context).size.width >= 600 && _selectedTabIndex == 0)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddFactoryScreen()),
                );
                _fetchFactories();
              },
              backgroundColor: _primaryColor,
              icon: const Icon(Icons.business, color: Colors.white),
              label: Text(
                AppStrings.addFactory,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFactoryListTab(),
          const AllFactoriesSummaryWidget(),
        ],
      ),
    );
  }

  Widget _buildFactoryListTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 48,
            child: TextField(
              decoration: InputDecoration(
                labelText: AppStrings.searchByNameOrNumber,
                prefixIcon: Icon(Icons.search, color: _textColorSecondary, size: 20),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _primaryColor),
                ),
              ),
              onChanged: (value) => setState(() {
                _searchQuery = value.toLowerCase();
                _currentPage = 0;
              }),
            ),
          ),
          const SizedBox(height: 16),
          if (_errorMessage != null)
            Center(
              child: Text(
                "${AppStrings.errorPrefix}$_errorMessage",
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_cachedFactories == null)
            _buildSkeletonList()
          else
            Builder(
              builder: (context) {
                var filteredDocs = _cachedFactories!.where((data) {
                  String name = (data['name'] ?? '').toString().toLowerCase();
                  String ref = (data['refNumber'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || ref.contains(_searchQuery);
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(AppStrings.noFactoriesFound),
                    ),
                  );
                }

                int totalPages = (filteredDocs.length / _itemsPerPage).ceil();
                if (_currentPage >= totalPages && totalPages > 0) {
                  _currentPage = totalPages - 1;
                }

                var paginatedDocs = filteredDocs
                    .skip(_currentPage * _itemsPerPage)
                    .take(_itemsPerPage)
                    .toList();

                return Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedDocs.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildResponsiveFactoryItem(
                        paginatedDocs[index]['id'],
                        paginatedDocs[index],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (totalPages > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, size: 16),
                            onPressed: _currentPage > 0
                                ? () => setState(() => _currentPage--)
                                : null,
                          ),
                          Text('${AppStrings.page} ${_currentPage + 1} / $totalPages'),
                          IconButton(
                            icon: const Icon(Icons.arrow_forward_ios, size: 16),
                            onPressed: _currentPage < totalPages - 1
                                ? () => setState(() => _currentPage++)
                                : null,
                          ),
                        ],
                      )
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
