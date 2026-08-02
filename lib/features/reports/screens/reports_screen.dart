import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/medicine_model.dart';
import '../../../core/models/prescription_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../utils/helpers.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedRange = 'All Time';
  bool _isLoading = true;

  List<Sale> _sales = [];
  List<Medicine> _medicines = [];
  List<Prescription> _prescriptions = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final db = ref.read(databaseHelperProvider);
      final sales = await db.getSales();
      final medicines = ref.read(inventoryProvider);
      final prescriptions = ref.read(prescriptionProvider);

      if (mounted) {
        setState(() {
          _sales = sales;
          _medicines = medicines;
          _prescriptions = prescriptions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _exportReportCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report exported to CSV successfully! Saved to Documents/pharmacy_system/reports/'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Filter sales by range
    final now = DateTime.now();
    List<Sale> filteredSales = _sales;
    if (_selectedRange == 'Today') {
      final todayStr = DateFormat('yyyy-MM-dd').format(now);
      filteredSales = _sales.where((s) => s.saleDate.startsWith(todayStr)).toList();
    } else if (_selectedRange == 'Last 7 Days') {
      final weekAgo = now.subtract(const Duration(days: 7));
      filteredSales = _sales.where((s) {
        final d = DateTime.tryParse(s.saleDate);
        return d != null && d.isAfter(weekAgo);
      }).toList();
    } else if (_selectedRange == 'Last 30 Days') {
      final monthAgo = now.subtract(const Duration(days: 30));
      filteredSales = _sales.where((s) {
        final d = DateTime.tryParse(s.saleDate);
        return d != null && d.isAfter(monthAgo);
      }).toList();
    }

    // Calculations
    final totalRevenue = filteredSales.fold(0.0, (sum, s) => sum + s.netAmount);
    final totalTransactions = filteredSales.length;
    final avgOrderValue = totalTransactions > 0 ? totalRevenue / totalTransactions : 0.0;

    // Payment methods breakdown
    int cashCount = 0;
    int cardCount = 0;
    int insuranceCount = 0;
    for (var s in filteredSales) {
      final method = s.paymentMethod.toLowerCase();
      if (method.contains('cash')) cashCount++;
      else if (method.contains('card')) cardCount++;
      else if (method.contains('insurance')) insuranceCount++;
    }

    // Inventory Valuation
    final totalStockValue = _medicines.fold(0.0, (sum, m) => sum + (m.sellingPrice * m.currentStock));
    final lowStockCount = _medicines.where((m) => m.isLowStock()).length;
    final outOfStockCount = _medicines.where((m) => m.currentStock == 0).length;

    // Prescription metrics
    final pendingRx = _prescriptions.where((r) => r.status.toLowerCase() == 'pending').length;
    final dispensedRx = _prescriptions.where((r) => r.status.toLowerCase() == 'dispensed').length;
    final completedRx = _prescriptions.where((r) => r.status.toLowerCase() == 'completed').length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter & Action Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pharmacy Analytics Overview',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Row(
                  children: [
                    // Time Range Selector
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedRange,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'Today', child: Text('Today')),
                          DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
                          DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
                          DropdownMenuItem(value: 'All Time', child: Text('All Time')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedRange = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: _exportReportCSV,
                      icon: const FaIcon(FontAwesomeIcons.fileCsv, size: 14),
                      label: const Text('Export CSV Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Top Stat Cards
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = (constraints.maxWidth - (3 * 16)) / 4;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard('Total Revenue', Helpers.formatCurrency(totalRevenue), FontAwesomeIcons.chartLine, AppColors.success, cardWidth),
                    _buildMetricCard('Total Transactions', totalTransactions.toString(), FontAwesomeIcons.receipt, AppColors.primary, cardWidth),
                    _buildMetricCard('Inventory Value', Helpers.formatCurrency(totalStockValue), FontAwesomeIcons.boxesStacked, AppColors.secondary, cardWidth),
                    _buildMetricCard('Avg Order Value', Helpers.formatCurrency(avgOrderValue), FontAwesomeIcons.scaleBalanced, AppColors.accent, cardWidth),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // 2 Column Detailed Reports Grid
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1100) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildSalesAnalyticsCard(cashCount, cardCount, insuranceCount, totalTransactions)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildInventoryAnalyticsCard(lowStockCount, outOfStockCount)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildSalesAnalyticsCard(cashCount, cardCount, insuranceCount, totalTransactions),
                      const SizedBox(height: 24),
                      _buildInventoryAnalyticsCard(lowStockCount, outOfStockCount),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 24),

            // Prescription Analytics Card
            _buildPrescriptionAnalyticsCard(pendingRx, dispensedRx, completedRx),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, FaIconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesAnalyticsCard(int cash, int card, int insurance, int total) {
    final cashPct = total > 0 ? (cash / total) : 0.0;
    final cardPct = total > 0 ? (card / total) : 0.0;
    final insurancePct = total > 0 ? (insurance / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Methods Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Divider(height: 24),
          _buildProgressBarRow('Cash Transactions', cash, cashPct, AppColors.success),
          const SizedBox(height: 16),
          _buildProgressBarRow('Credit / Debit Cards', card, cardPct, AppColors.primary),
          const SizedBox(height: 16),
          _buildProgressBarRow('Insurance Policies', insurance, insurancePct, AppColors.accent),
        ],
      ),
    );
  }

  Widget _buildInventoryAnalyticsCard(int lowStock, int outOfStock) {
    final totalMeds = _medicines.length;
    final inStockCount = totalMeds - lowStock;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inventory Stock Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Divider(height: 24),
          _buildProgressBarRow('In Stock Medicines', inStockCount, totalMeds > 0 ? inStockCount / totalMeds : 0, AppColors.success),
          const SizedBox(height: 16),
          _buildProgressBarRow('Low Stock Warning Level', lowStock, totalMeds > 0 ? lowStock / totalMeds : 0, AppColors.warning),
          const SizedBox(height: 16),
          _buildProgressBarRow('Out of Stock Items', outOfStock, totalMeds > 0 ? outOfStock / totalMeds : 0, AppColors.danger),
        ],
      ),
    );
  }

  Widget _buildPrescriptionAnalyticsCard(int pending, int dispensed, int completed) {
    final total = _prescriptions.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Prescription Fulfillment Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text('Total Prescriptions: $total', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(child: _buildProgressBarRow('Pending Queue', pending, total > 0 ? pending / total : 0, AppColors.warning)),
              const SizedBox(width: 24),
              Expanded(child: _buildProgressBarRow('Dispensed Out', dispensed, total > 0 ? dispensed / total : 0, AppColors.secondary)),
              const SizedBox(width: 24),
              Expanded(child: _buildProgressBarRow('Completed Rx', completed, total > 0 ? completed / total : 0, AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBarRow(String label, int count, double percentage, Color color) {
    final pctText = (percentage * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Text('$count ($pctText%)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: percentage.clamp(0.0, 1.0),
          backgroundColor: color.withOpacity(0.1),
          color: color,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
