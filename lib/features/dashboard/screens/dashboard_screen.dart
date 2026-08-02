import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/medicine_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../utils/helpers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  double _todaySalesAmount = 0.0;
  List<Sale> _recentSales = [];
  bool _isLoadingSales = true;

  @override
  void initState() {
    super.initState();
    _fetchSalesData();
  }

  Future<void> _fetchSalesData() async {
    try {
      final salesNotifier = ref.read(salesProvider.notifier);
      final todaySales = await salesNotifier.getTodaySales();
      final allSales = await salesNotifier.getSalesHistory();

      double total = todaySales.fold(0.0, (sum, sale) => sum + sale.netAmount);
      
      // Sort and take last 5 for recent transactions
      final recent = allSales.take(5).toList();

      if (mounted) {
        setState(() {
          _todaySalesAmount = total;
          _recentSales = recent;
          _isLoadingSales = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSales = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(inventoryProvider);
    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    final prescriptionNotifier = ref.read(prescriptionProvider.notifier);
    final prescriptions = ref.watch(prescriptionProvider);

    final totalMedicines = medicines.length;
    final lowStockCount = inventoryNotifier.getLowStockMedicines().length;
    final pendingRxCount = prescriptionNotifier.getPendingPrescriptions().length;

    // Get expiring medicines (30 days)
    final expiringMedicines = inventoryNotifier.getExpiringMedicines(30);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(inventoryProvider.notifier).loadMedicines();
          await ref.read(prescriptionProvider.notifier).loadPrescriptions();
          await _fetchSalesData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(AppTheme.sectionPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              const Text(
                'Welcome Back, Pharmacist',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Here is the status of your pharmacy for today.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards Row
              LayoutBuilder(
                builder: (context, constraints) {
                  double cardWidth = (constraints.maxWidth - (3 * AppTheme.defaultPadding)) / 4;
                  if (constraints.maxWidth < 768) {
                    // Wrap if screen gets extremely small
                    return Wrap(
                      spacing: AppTheme.defaultPadding,
                      runSpacing: AppTheme.defaultPadding,
                      children: [
                        _buildStatCard('Total Medicines', totalMedicines.toString(), FontAwesomeIcons.pills, AppColors.primary, constraints.maxWidth / 2 - 12),
                        _buildStatCard('Low Stock Alerts', lowStockCount.toString(), FontAwesomeIcons.triangleExclamation, AppColors.warning, constraints.maxWidth / 2 - 12),
                        _buildStatCard("Today's Sales", Helpers.formatCurrency(_todaySalesAmount), FontAwesomeIcons.rupeeSign, AppColors.success, constraints.maxWidth / 2 - 12),
                        _buildStatCard('Pending Prescriptions', pendingRxCount.toString(), FontAwesomeIcons.filePrescription, AppColors.accent, constraints.maxWidth / 2 - 12),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatCard('Total Medicines', totalMedicines.toString(), FontAwesomeIcons.pills, AppColors.primary, cardWidth),
                      _buildStatCard('Low Stock Alerts', lowStockCount.toString(), FontAwesomeIcons.triangleExclamation, AppColors.warning, cardWidth),
                      _buildStatCard("Today's Sales", Helpers.formatCurrency(_todaySalesAmount), FontAwesomeIcons.rupeeSign, AppColors.success, cardWidth),
                      _buildStatCard('Pending Prescriptions', pendingRxCount.toString(), FontAwesomeIcons.filePrescription, AppColors.accent, cardWidth),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // Two Column Layout for details (Recent Sales and Expiry alerts)
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth > 1200) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _buildRecentSalesCard(),
                        ),
                        SizedBox(width: AppTheme.sectionPadding),
                        Expanded(
                          flex: 2,
                          child: _buildExpiryAlertsCard(expiringMedicines),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        _buildRecentSalesCard(),
                        const SizedBox(height: 24),
                        _buildExpiryAlertsCard(expiringMedicines),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, FaIconData icon, Color color, double width) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(
              icon,
              color: color,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/sales/history');
                },
                child: const Text('View All'),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_isLoadingSales)
            const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
          else if (_recentSales.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No sales transactions recorded today.', style: TextStyle(color: AppColors.textSecondary))))
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 500),
                child: DataTable(
                  horizontalMargin: 0,
                  columnSpacing: 24,
                  columns: const [
                    DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  ],
                  rows: _recentSales.map((sale) {
                    final date = DateTime.tryParse(sale.saleDate) ?? DateTime.now();
                    final formattedDate = DateFormat('MMM d, hh:mm a').format(date);
                    return DataRow(
                      cells: [
                        DataCell(
                          InkWell(
                            onTap: () => context.go('/sales/invoice/${sale.id}'),
                            child: Text(
                              sale.invoiceNumber,
                              style: const TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        DataCell(Text(sale.customerName ?? 'Walk-in')),
                        DataCell(Text(Helpers.formatCurrency(sale.netAmount))),
                        DataCell(Text(formattedDate)),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpiryAlertsCard(List<Medicine> expiring) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expiry Alerts (Next 30 Days)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 24),
          if (expiring.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40.0),
              child: Center(
                child: Text(
                  'No medicines expiring soon.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: expiring.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final med = expiring[index];
                final expiry = DateTime.parse(med.expiryDate!);
                final daysRemaining = expiry.difference(DateTime.now()).inDays;
                
                Color statusColor = AppColors.success;
                if (daysRemaining < 7) {
                  statusColor = AppColors.danger; // Red
                } else if (daysRemaining <= 15) {
                  statusColor = AppColors.warning; // Orange
                } else {
                  statusColor = Colors.orangeAccent; // Yellowish-orange
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.name,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expiry: ${med.expiryDate} ($daysRemaining days remaining)',
                            style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Stock: ${med.currentStock}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          med.batchNumber ?? 'No Batch',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
