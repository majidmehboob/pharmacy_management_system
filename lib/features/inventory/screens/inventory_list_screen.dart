import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/medicine_model.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  const InventoryListScreen({super.key});

  @override
  ConsumerState<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends ConsumerState<InventoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  int _currentPage = 1;
  static const int _itemsPerPage = 10;

  final List<String> _categories = [
    'All',
    'Antibiotics',
    'Pain Relief',
    'Vitamins & Supplements',
    'Blood Pressure',
    'Diabetes',
    'Allergy',
    'Skin Care',
    'Digestive Health',
    'Respiratory',
    'Cardiovascular',
    'Neurological',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    ref.read(inventoryProvider.notifier).searchMedicines(_searchController.text);
    setState(() {
      _currentPage = 1; // Reset to page 1 on search
    });
  }

  @override
  Widget build(BuildContext context) {
    var medicines = ref.watch(inventoryProvider);

    // Apply category filtering locally on top of search state
    if (_selectedCategory != 'All') {
      medicines = medicines.where((med) => med.category == _selectedCategory).toList();
    }

    // Pagination calculations
    final totalItems = medicines.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    final paginatedMedicines = medicines.sublist(
      startIndex,
      endIndex > totalItems ? totalItems : endIndex,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Search & Filters & Add Button
            Row(
              children: [
                // Search bar
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search medicine by name or generic name...',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 16, color: AppColors.textSecondary),
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
                
                // Category Filter
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category Filter',
                    ),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategory = val ?? 'All';
                        _currentPage = 1;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Add Medicine Button
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/inventory/add');
                  },
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: const Text('Add Medicine'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Table Card
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Table header & Body
                    Expanded(
                      child: medicines.isEmpty
                          ? const Center(
                              child: Text(
                                'No medicines found matching criteria.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                              ),
                            )
                          : SingleChildScrollView(
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
                                      DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Generic Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Current Stock', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Selling Price', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Expiry Date', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                    ],
                                    rows: paginatedMedicines.map((med) {
                                      final status = med.getStatus();
                                      
                                      // Status style
                                      Color statusColor = AppColors.success;
                                      Color statusBg = AppColors.success.withOpacity(0.1);
                                      if (status == 'Expired') {
                                        statusColor = AppColors.warning;
                                        statusBg = AppColors.warning.withOpacity(0.1);
                                      } else if (status == 'Out of Stock') {
                                        statusColor = AppColors.danger;
                                        statusBg = AppColors.danger.withOpacity(0.1);
                                      } else if (status == 'Low Stock') {
                                        statusColor = AppColors.danger;
                                        statusBg = AppColors.danger.withOpacity(0.05);
                                      } else if (status == 'Discontinued') {
                                        statusColor = AppColors.textSecondary;
                                        statusBg = AppColors.border;
                                      }

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(med.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                                          DataCell(Text(med.genericName ?? 'N/A')),
                                          DataCell(Text(med.category ?? 'N/A')),
                                          DataCell(
                                            Text(
                                              med.currentStock.toString(),
                                              style: TextStyle(
                                                color: med.isLowStock() ? AppColors.danger : AppColors.textPrimary,
                                                fontWeight: med.isLowStock() ? FontWeight.bold : FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          DataCell(Text('\$${med.sellingPrice.toStringAsFixed(2)}')),
                                          DataCell(Text(med.expiryDate ?? 'N/A')),
                                          DataCell(
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: statusBg,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Row(
                                              children: [
                                                IconButton(
                                                  icon: const FaIcon(FontAwesomeIcons.penToSquare, size: 14, color: AppColors.secondary),
                                                  onPressed: () {
                                                    context.go('/inventory/edit/${med.id}');
                                                  },
                                                ),
                                                IconButton(
                                                  icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14, color: AppColors.danger),
                                                  onPressed: () => _confirmDelete(context, med),
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
                    
                    // Pagination Footer
                    if (totalPages > 1) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${startIndex + 1} to ${endIndex > totalItems ? totalItems : endIndex} of $totalItems entries',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: _currentPage > 1
                                      ? () => setState(() => _currentPage--)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Previous'),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Text(
                                    'Page $_currentPage of $totalPages',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  onPressed: _currentPage < totalPages
                                      ? () => setState(() => _currentPage++)
                                      : null,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  ),
                                  child: const Text('Next'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Medicine medicine) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Medicine'),
          content: Text('Are you sure you want to delete ${medicine.name}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                ref.read(inventoryProvider.notifier).deleteMedicine(medicine.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${medicine.name} deleted successfully.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
