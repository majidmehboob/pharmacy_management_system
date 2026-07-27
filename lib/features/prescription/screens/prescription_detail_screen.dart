import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/prescription_model.dart';

class PrescriptionDetailScreen extends ConsumerStatefulWidget {
  final String prescriptionId;
  const PrescriptionDetailScreen({super.key, required this.prescriptionId});

  @override
  ConsumerState<PrescriptionDetailScreen> createState() => _PrescriptionDetailScreenState();
}

class _PrescriptionDetailScreenState extends ConsumerState<PrescriptionDetailScreen> {
  bool _isLoading = true;
  Prescription? _prescription;

  @override
  void initState() {
    super.initState();
    _loadPrescription();
  }

  Future<void> _loadPrescription() async {
    final db = ref.read(databaseHelperProvider);
    final rx = await db.getPrescriptionById(widget.prescriptionId);
    if (mounted) {
      setState(() {
        _prescription = rx;
        _isLoading = false;
      });
    }
  }

  void _handleDispense() async {
    if (_prescription == null) return;
    
    setState(() {
      _isLoading = true;
    });

    final success = await ref.read(prescriptionProvider.notifier).dispensePrescription(_prescription!.id);
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription dispensed successfully! Stock levels updated.')),
      );
      await _loadPrescription();
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to dispense. Insufficient medicine stock available!'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _handleDelete() {
    if (_prescription == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Prescription'),
          content: Text('Are you sure you want to delete ${_prescription!.prescriptionNumber}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref.read(prescriptionProvider.notifier).deletePrescription(_prescription!.id);
                Navigator.pop(context);
                context.go('/prescriptions');
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _handlePrint() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sent prescription to default printer...')),
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

    if (_prescription == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Prescription not found.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/prescriptions'),
                child: const Text('Back to Prescriptions'),
              )
            ],
          ),
        ),
      );
    }

    final rx = _prescription!;
    final date = DateTime.tryParse(rx.prescribedDate) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(date);
    final availableMeds = ref.watch(inventoryProvider);
    final canDispense = rx.canDispense(availableMeds);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header bar
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/prescriptions'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Prescription: ${rx.prescriptionNumber}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                
                // Actions
                OutlinedButton.icon(
                  onPressed: _handlePrint,
                  icon: const FaIcon(FontAwesomeIcons.print, size: 14),
                  label: const Text('Print Rx'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _handleDelete,
                  icon: const FaIcon(FontAwesomeIcons.trash, size: 14, color: AppColors.danger),
                  label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Timeline Card
            _buildTimelineCard(rx.status),
            const SizedBox(height: 24),

            // 2 Column details
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 1000) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildInfoCard(rx, formattedDate)),
                      const SizedBox(width: 24),
                      Expanded(flex: 3, child: _buildMedicinesCard(rx, canDispense)),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      _buildInfoCard(rx, formattedDate),
                      const SizedBox(height: 24),
                      _buildMedicinesCard(rx, canDispense),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(String status) {
    // Determine active steps
    final statusList = ['pending', 'dispensed', 'completed'];
    final activeIndex = statusList.indexOf(status.toLowerCase());
    
    // Helper to draw step
    Widget buildStep(String label, int index) {
      final isCompleted = activeIndex >= index;
      final isActive = activeIndex == index;
      
      Color dotColor = Colors.grey.shade300;
      if (isCompleted) dotColor = AppColors.success;
      if (isActive) dotColor = AppColors.primary;

      return Column(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: dotColor,
            child: Icon(
              isCompleted ? Icons.check : Icons.circle,
              color: Colors.white,
              size: isCompleted ? 16 : 10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isCompleted || isActive ? FontWeight.bold : FontWeight.normal,
              color: isCompleted || isActive ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          buildStep('Created & Pending', 0),
          Expanded(child: Container(height: 2, color: activeIndex >= 1 ? AppColors.success : Colors.grey.shade300)),
          buildStep('Dispensed Out', 1),
          Expanded(child: Container(height: 2, color: activeIndex >= 2 ? AppColors.success : Colors.grey.shade300)),
          buildStep('Completed Transaction', 2),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Prescription rx, String formattedDate) {
    Widget buildDetailRow(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }

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
          const Text('Patient Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const Divider(height: 24),
          buildDetailRow('Patient Name:', rx.patientName),
          buildDetailRow('Age:', rx.patientAge != null ? '${rx.patientAge} years' : 'N/A'),
          buildDetailRow('Gender:', rx.patientGender ?? 'N/A'),
          buildDetailRow('Phone Number:', rx.patientPhone ?? 'N/A'),
          const SizedBox(height: 20),
          const Text('Doctor Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const Divider(height: 24),
          buildDetailRow('Doctor Name:', rx.doctorName ?? 'N/A'),
          buildDetailRow('License Number:', rx.doctorLicense ?? 'N/A'),
          buildDetailRow('Prescribed Date:', formattedDate),
          if (rx.notes != null && rx.notes!.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Notes & Instructions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const Divider(height: 24),
            Text(
              rx.notes!,
              style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicinesCard(Prescription rx, bool canDispense) {
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
          const Text('Prescribed Medicines', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const Divider(height: 24),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rx.items.length,
            separatorBuilder: (context, index) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = rx.items[index];
              final medicine = item.medicine;
              final currentStock = medicine?.currentStock ?? 0;
              final stockError = currentStock < item.quantity && rx.status == 'pending';

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicine?.name ?? 'Unknown Medicine',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dosage: ${item.dosage} • Frequency: ${item.frequency} • Duration: ${item.duration}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Qty: ${item.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      if (rx.status == 'pending') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Available Stock: $currentStock',
                          style: TextStyle(
                            fontSize: 12,
                            color: stockError ? AppColors.danger : AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ]
                    ],
                  ),
                ],
              );
            },
          ),
          
          // Dispensing action trigger
          if (rx.status.toLowerCase() == 'pending') ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Divider(color: AppColors.border),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (!canDispense)
                  const Expanded(
                    child: Text(
                      'Cannot dispense. Some medicines in the prescription do not have enough stock.',
                      style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  )
                else
                  const Spacer(),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: canDispense ? _handleDispense : null,
                  icon: const FaIcon(FontAwesomeIcons.handHoldingMedical, size: 14),
                  label: const Text('Dispense Prescription Now'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                ),
              ],
            )
          ]
        ],
      ),
    );
  }
}
