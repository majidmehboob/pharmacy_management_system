import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/medicine_model.dart';
import '../../../core/models/prescription_model.dart';

class CreatePrescriptionScreen extends ConsumerStatefulWidget {
  const CreatePrescriptionScreen({super.key});

  @override
  ConsumerState<CreatePrescriptionScreen> createState() => _CreatePrescriptionScreenState();
}

class _CreatePrescriptionScreenState extends ConsumerState<CreatePrescriptionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Patient Info controllers
  final TextEditingController _patientNameController = TextEditingController();
  final TextEditingController _patientPhoneController = TextEditingController();
  final TextEditingController _patientAgeController = TextEditingController();
  String _selectedGender = 'Male';

  // Prescription Details controllers
  late String _prescriptionNumber;
  final TextEditingController _prescribedDateController = TextEditingController();
  final TextEditingController _doctorNameController = TextEditingController();
  final TextEditingController _doctorLicenseController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  // Prescribed Medicines list
  final List<PrescriptionItemDraft> _itemsDraft = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prescriptionNumber = Prescription.generatePrescriptionNumber();
    _prescribedDateController.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    // Add one empty item row by default
    _addItemRow();
  }

  @override
  void dispose() {
    _patientNameController.dispose();
    _patientPhoneController.dispose();
    _patientAgeController.dispose();
    _prescribedDateController.dispose();
    _doctorNameController.dispose();
    _doctorLicenseController.dispose();
    _notesController.dispose();
    for (var draft in _itemsDraft) {
      draft.dispose();
    }
    super.dispose();
  }

  void _addItemRow() {
    setState(() {
      _itemsDraft.add(PrescriptionItemDraft());
    });
  }

  void _removeItemRow(int index) {
    if (_itemsDraft.length > 1) {
      setState(() {
        final draft = _itemsDraft.removeAt(index);
        draft.dispose();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prescription must contain at least one medicine.')),
      );
    }
  }

  Future<void> _selectPrescribedDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(), // cannot be future date
    );
    if (picked != null) {
      setState(() {
        _prescribedDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _savePrescription(String status) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Custom validations
    // 1. Verify at least one medicine has been selected
    bool hasMedicines = true;
    for (int i = 0; i < _itemsDraft.length; i++) {
      if (_itemsDraft[i].selectedMedicine == null) {
        hasMedicines = false;
        break;
      }
    }
    if (!hasMedicines) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a medicine for all rows.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // 2. Doctor Name is required if status is 'dispensed' or 'completed'
    if ((status == 'dispensed' || status == 'completed') && _doctorNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Doctor Name is required when dispensing.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // 3. Stock verification if status is 'dispensed'
    if (status == 'dispensed') {
      final availableMedicines = ref.read(inventoryProvider);
      bool enoughStock = true;
      String lowStockMedName = '';

      for (var draft in _itemsDraft) {
        final med = availableMedicines.firstWhere((m) => m.id == draft.selectedMedicine!.id);
        final qty = int.tryParse(draft.quantityController.text) ?? 0;
        if (med.currentStock < qty) {
          enoughStock = false;
          lowStockMedName = med.name;
          break;
        }
      }

      if (!enoughStock) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Insufficient stock available for $lowStockMedName.'), backgroundColor: AppColors.danger),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now().toIso8601String();
    final prescriptionId = const Uuid().v4();

    // Construct prescription items
    final List<PrescriptionItem> items = _itemsDraft.map((draft) {
      return PrescriptionItem(
        id: const Uuid().v4(),
        prescriptionId: prescriptionId,
        medicineId: draft.selectedMedicine!.id,
        dosage: draft.dosageController.text.trim(),
        frequency: draft.frequencyController.text.trim(),
        duration: draft.durationController.text.trim(),
        quantity: int.parse(draft.quantityController.text),
        dispensed: status == 'dispensed',
      );
    }).toList();

    final prescription = Prescription(
      id: prescriptionId,
      prescriptionNumber: _prescriptionNumber,
      patientName: _patientNameController.text.trim(),
      patientPhone: _patientPhoneController.text.trim().isEmpty ? null : _patientPhoneController.text.trim(),
      patientAge: int.tryParse(_patientAgeController.text),
      patientGender: _selectedGender,
      doctorName: _doctorNameController.text.trim().isEmpty ? null : _doctorNameController.text.trim(),
      doctorLicense: _doctorLicenseController.text.trim().isEmpty ? null : _doctorLicenseController.text.trim(),
      prescribedDate: _prescribedDateController.text,
      status: status,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: now,
      updatedAt: now,
      items: items,
    );

    try {
      if (status == 'dispensed') {
        // Save as pending first
        final pendingRx = prescription.copyWith(status: 'pending');
        await ref.read(prescriptionProvider.notifier).createPrescription(pendingRx);
        // Then call dispense, which handles database updates & stock deduction
        await ref.read(prescriptionProvider.notifier).dispensePrescription(prescriptionId);
      } else {
        await ref.read(prescriptionProvider.notifier).createPrescription(prescription);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prescription saved successfully! Status: ${status.toUpperCase()}')),
        );
        context.go('/prescriptions');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save prescription. Please try again.'), backgroundColor: AppColors.danger),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final availableMedicines = ref.watch(inventoryProvider).where((m) => m.isActive).toList();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/prescriptions'),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Create New Prescription',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    'No: $_prescriptionNumber',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 1: Patient Information Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _patientNameController,
                            decoration: const InputDecoration(
                              labelText: 'Patient Name *',
                              hintText: 'e.g. John Doe',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Patient name is required';
                              if (val.trim().length < 2) return 'Must be at least 2 characters';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _patientPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: 'e.g. 1234567890',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _patientAgeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Age',
                              hintText: 'e.g. 35',
                            ),
                            validator: (val) {
                              if (val != null && val.isNotEmpty) {
                                final a = int.tryParse(val);
                                if (a == null || a <= 0) return 'Must be a positive integer';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          flex: 1,
                          child: DropdownButtonFormField<String>(
                            value: _selectedGender,
                            decoration: const InputDecoration(
                              labelText: 'Gender',
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text('Male')),
                              DropdownMenuItem(value: 'Female', child: Text('Female')),
                              DropdownMenuItem(value: 'Other', child: Text('Other')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedGender = val;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 2: Prescription details (Doctor, date, license, notes)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Prescription Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _prescribedDateController,
                            readOnly: true,
                            onTap: () => _selectPrescribedDate(context),
                            decoration: const InputDecoration(
                              labelText: 'Prescribed Date *',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Date is required';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _doctorNameController,
                            decoration: const InputDecoration(
                              labelText: 'Doctor Name',
                              hintText: 'e.g. Dr. Sarah Jenkins',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _doctorLicenseController,
                            decoration: const InputDecoration(
                              labelText: 'Doctor License Number',
                              hintText: 'e.g. LIC-98765',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Notes & Special Instructions',
                        hintText: 'e.g. Take after meals, watch for allergic responses...',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 3: Prescribed Medicines Card list
              Container(
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
                        const Text('Prescribed Medicines *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ElevatedButton.icon(
                          onPressed: _addItemRow,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Medicine Row'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    
                    // Table Rows
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _itemsDraft.length,
                      itemBuilder: (context, index) {
                        final draft = _itemsDraft[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Auto-complete Medicine Search
                              Expanded(
                                flex: 4,
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Autocomplete<Medicine>(
                                      displayStringForOption: (Medicine option) => option.name,
                                      optionsBuilder: (TextEditingValue textEditingValue) {
                                        if (textEditingValue.text.isEmpty) {
                                          return const Iterable<Medicine>.empty();
                                        }
                                        return availableMedicines.where((Medicine option) {
                                          return option.name.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                                              (option.genericName ?? '').toLowerCase().contains(textEditingValue.text.toLowerCase());
                                        });
                                      },
                                      onSelected: (Medicine selection) {
                                        setState(() {
                                          draft.selectedMedicine = selection;
                                          draft.quantityController.text = '1';
                                        });
                                      },
                                      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                                        // Sync custom selection if needed
                                        if (draft.selectedMedicine == null && textController.text.isNotEmpty) {
                                          textController.clear();
                                        }
                                        return TextFormField(
                                          controller: textController,
                                          focusNode: focusNode,
                                          decoration: InputDecoration(
                                            labelText: 'Search Medicine *',
                                            hintText: 'Type name...',
                                            suffixIcon: draft.selectedMedicine != null
                                                ? Text(
                                                    'Stock: ${draft.selectedMedicine!.currentStock}  ',
                                                    style: TextStyle(
                                                      color: draft.selectedMedicine!.isLowStock() ? AppColors.danger : AppColors.textSecondary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          validator: (val) {
                                            if (draft.selectedMedicine == null) return 'Select medicine';
                                            return null;
                                          },
                                        );
                                      },
                                      optionsViewBuilder: (context, onSelected, options) {
                                        return Align(
                                          alignment: Alignment.topLeft,
                                          child: Material(
                                            elevation: 4.0,
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              width: constraints.maxWidth,
                                              height: 200,
                                              decoration: BoxDecoration(
                                                border: Border.all(color: AppColors.border),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: ListView.builder(
                                                padding: EdgeInsets.zero,
                                                itemCount: options.length,
                                                itemBuilder: (BuildContext context, int index) {
                                                  final Medicine option = options.elementAt(index);
                                                  return ListTile(
                                                    title: Text(option.name),
                                                    subtitle: Text('${option.genericName ?? ""} • Stock: ${option.currentStock}'),
                                                    onTap: () {
                                                      onSelected(option);
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              
                              // Dosage input
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: draft.dosageController,
                                  decoration: const InputDecoration(
                                    labelText: 'Dosage *',
                                    hintText: 'e.g. 1 tab',
                                  ),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Frequency input
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: draft.frequencyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Frequency *',
                                    hintText: 'e.g. 3x daily',
                                  ),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Duration input
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: draft.durationController,
                                  decoration: const InputDecoration(
                                    labelText: 'Duration *',
                                    hintText: 'e.g. 7 days',
                                  ),
                                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Quantity input
                              Expanded(
                                flex: 1,
                                child: TextFormField(
                                  controller: draft.quantityController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty *',
                                    hintText: '1',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return 'Req';
                                    final q = int.tryParse(val);
                                    if (q == null || q <= 0) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Delete row button
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                                  onPressed: () => _removeItemRow(index),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Actions Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/prescriptions'),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _savePrescription('pending'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                    child: const Text('Save Prescription (Pending)'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () => _savePrescription('dispensed'),
                    child: const Text('Dispense Now'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper Draft model to contain form controllers in list view
class PrescriptionItemDraft {
  Medicine? selectedMedicine;
  final TextEditingController dosageController = TextEditingController();
  final TextEditingController frequencyController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();

  void dispose() {
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    quantityController.dispose();
  }
}
