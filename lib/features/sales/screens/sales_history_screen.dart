import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/sale_model.dart';
import '../../../utils/helpers.dart';

class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Sale> _sales = [];
  bool _isLoading = true;

  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _fetchSales();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSales() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final notifier = ref.read(salesProvider.notifier);
      List<Sale> allSales = [];
      
      if (_selectedDateRange != null) {
        final start = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start);
        // Add 1 day to end date to query till end of day
        final end = DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end.add(const Duration(days: 1)));
        allSales = await notifier.getSalesHistory();
        
        // Filter by date range locally for accuracy
        allSales = allSales.where((s) {
          try {
            final date = DateTime.parse(s.saleDate);
            return date.isAfter(_selectedDateRange!.start.subtract(const Duration(seconds: 1))) &&
                date.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
          } catch (_) {
            return false;
          }
        }).toList();
      } else {
        allSales = await notifier.getSalesHistory();
      }

      setState(() {
        _sales = allSales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    _fetchSales();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchSales();
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
    });
    _fetchSales();
  }

  @override
  Widget build(BuildContext context) {
    // Filter locally by search query
    final query = _searchController.text.toLowerCase().trim();
    final filteredSales = _sales.where((sale) {
      if (query.isEmpty) return true;
      return sale.invoiceNumber.toLowerCase().contains(query) ||
          (sale.customerName ?? '').toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search and Date Range Header Row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search sales by invoice # or customer...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14, color: AppColors.textSecondary),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Date Range Button
                OutlinedButton.icon(
                  onPressed: () => _selectDateRange(context),
                  icon:  FaIcon(FontAwesomeIcons.calendarCheck, size: 14),
                  label: Text(
                    _selectedDateRange == null
                        ? 'Filter by Date Range'
                        : '${DateFormat('MM/dd').format(_selectedDateRange!.start)} - ${DateFormat('MM/dd').format(_selectedDateRange!.end)}',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
                if (_selectedDateRange != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, color: AppColors.danger),
                    onPressed: _clearDateFilter,
                  ),
                ],
                const SizedBox(width: 16),
                
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/sales/pos');
                  },
                  icon: const FaIcon(FontAwesomeIcons.cashRegister, size: 14),
                  label: const Text('Go to POS'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sales History Table Card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredSales.isEmpty
                        ? const Center(
                            child: Text(
                              'No transactions found for the selected filter.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minWidth: MediaQuery.of(context).size.width - 320,
                                      ),
                                      child: DataTable(
                                        headingRowColor: MaterialStateProperty.all(AppColors.background),
                                        columns: const [
                                          DataColumn(label: Text('Invoice #', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Customer', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Sale Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Items Count', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Net Amount', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                          DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                        ],
                                        rows: filteredSales.map((sale) {
                                          final date = DateTime.tryParse(sale.saleDate) ?? DateTime.now();
                                          final formattedDate = DateFormat('yyyy-MM-dd hh:mm a').format(date);
                                          final isRefunded = sale.status == 'refunded';

                                          return DataRow(
                                            cells: [
                                              DataCell(
                                                Text(
                                                  sale.invoiceNumber,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                                                ),
                                              ),
                                              DataCell(Text(sale.customerName ?? 'Walk-in')),
                                              DataCell(Text(formattedDate)),
                                              DataCell(Text(sale.items.length.toString())),
                                              DataCell(Text(Helpers.formatCurrency(sale.netAmount))),
                                              DataCell(Text(sale.paymentMethod)),
                                              DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: isRefunded
                                                        ? AppColors.danger.withOpacity(0.1)
                                                        : AppColors.success.withOpacity(0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Text(
                                                    isRefunded ? 'Refunded' : 'Completed',
                                                    style: TextStyle(
                                                      color: isRefunded ? AppColors.danger : AppColors.success,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataCell(
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const FaIcon(FontAwesomeIcons.eye, size: 14, color: AppColors.secondary),
                                                      onPressed: () {
                                                        context.go('/sales/invoice/${sale.id}');
                                                      },
                                                      tooltip: 'View Invoice',
                                                    ),
                                                    if (!isRefunded)
                                                      IconButton(
                                                        icon: const FaIcon(FontAwesomeIcons.rotateLeft, size: 14, color: AppColors.danger),
                                                        onPressed: () => _confirmRefund(context, sale),
                                                        tooltip: 'Process Refund',
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmRefund(BuildContext context, Sale sale) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Refund Transaction'),
          content: Text('Are you sure you want to refund Invoice ${sale.invoiceNumber}? This will reverse the stock changes.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final db = ref.read(databaseHelperProvider);
                  // Update status to refunded
                  final updatedSale = sale.copyWith(status: 'refunded');
                  await db.updateSale(updatedSale);
                  
                  // Restore stock levels
                  for (final item in sale.items) {
                    await db.updateStock(item.medicineId, item.quantity);
                  }
                  
                  // Refresh inventory and fetch sales history
                  await ref.read(inventoryProvider.notifier).loadMedicines();
                  await _fetchSales();
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Refund processed successfully for Invoice ${sale.invoiceNumber}')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to process refund. Please try again.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Refund'),
            ),
          ],
        );
      },
    );
  }
}
