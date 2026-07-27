import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/prescription_model.dart';

class PrescriptionListScreen extends ConsumerStatefulWidget {
  const PrescriptionListScreen({super.key});

  @override
  ConsumerState<PrescriptionListScreen> createState() => _PrescriptionListScreenState();
}

class _PrescriptionListScreenState extends ConsumerState<PrescriptionListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';

  final List<String> _statuses = ['All', 'Pending', 'Dispensed', 'Completed', 'Cancelled'];

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
    ref.read(prescriptionProvider.notifier).getPrescriptionsByPatient(_searchController.text);
  }

  @override
  Widget build(BuildContext context) {
    var prescriptions = ref.watch(prescriptionProvider);

    // Apply status filter locally
    if (_selectedStatus != 'All') {
      prescriptions = prescriptions.where((rx) => rx.status.toLowerCase() == _selectedStatus.toLowerCase()).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Search & Filter Bar
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search prescriptions by patient name...',
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
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status Filter',
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedStatus = val ?? 'All';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    context.go('/prescriptions/create');
                  },
                  icon: const FaIcon(FontAwesomeIcons.plus, size: 14),
                  label: const Text('New Prescription'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Content Grid/List
            Expanded(
              child: prescriptions.isEmpty
                  ? const Center(
                      child: Text(
                        'No prescriptions found matching criteria.',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        int crossAxisCount = 3;
                        if (constraints.maxWidth < 768) {
                          crossAxisCount = 1;
                        } else if (constraints.maxWidth < 1200) {
                          crossAxisCount = 2;
                        }

                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            mainAxisExtent: 180,
                          ),
                          itemCount: prescriptions.length,
                          itemBuilder: (context, index) {
                            final rx = prescriptions[index];
                            return _buildPrescriptionCard(context, rx);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrescriptionCard(BuildContext context, Prescription rx) {
    final date = DateTime.tryParse(rx.prescribedDate) ?? DateTime.now();
    final formattedDate = DateFormat('MMM d, yyyy').format(date);
    final statusColor = rx.getStatusColor();

    return InkWell(
      onTap: () {
        context.go('/prescriptions/${rx.id}');
      },
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  rx.prescriptionNumber,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rx.getStatusText(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              rx.patientName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (rx.doctorName != null && rx.doctorName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Dr. ${rx.doctorName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.calendarDay, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Text(
                  '${rx.items.length} item(s)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
