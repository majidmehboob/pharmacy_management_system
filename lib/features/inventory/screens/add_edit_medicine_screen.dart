import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/medicine_model.dart';

class AddEditMedicineScreen extends ConsumerStatefulWidget {
  final String? medicineId;
  const AddEditMedicineScreen({super.key, this.medicineId});

  @override
  ConsumerState<AddEditMedicineScreen> createState() => _AddEditMedicineScreenState();
}

class _AddEditMedicineScreenState extends ConsumerState<AddEditMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late bool _isEditMode;
  bool _isLoading = true;

  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genericNameController = TextEditingController();
  final TextEditingController _manufacturerController = TextEditingController();
  final TextEditingController _purchasePriceController = TextEditingController();
  final TextEditingController _sellingPriceController = TextEditingController();
  final TextEditingController _currentStockController = TextEditingController();
  final TextEditingController _reorderLevelController = TextEditingController();
  final TextEditingController _batchNumberController = TextEditingController();
  final TextEditingController _expiryDateController = TextEditingController();

  String _selectedCategory = 'Other';
  bool _requiresPrescription = false;
  bool _isActive = true;

  final List<String> _categories = [
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
    _isEditMode = widget.medicineId != null;
    _reorderLevelController.text = '10';
    _currentStockController.text = '0';
    
    if (_isEditMode) {
      _loadMedicineData();
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _manufacturerController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _currentStockController.dispose();
    _reorderLevelController.dispose();
    _batchNumberController.dispose();
    _expiryDateController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicineData() async {
    final medId = widget.medicineId!;
    // Wait for inventory list to be loaded or load directly from list
    final medicines = ref.read(inventoryProvider);
    Medicine? medicine;
    
    try {
      medicine = medicines.firstWhere((m) => m.id == medId);
    } catch (_) {
      // Find in DB if not in provider list yet
      final db = ref.read(databaseHelperProvider);
      medicine = await db.getMedicineById(medId);
    }

    if (medicine != null) {
      _nameController.text = medicine.name;
      _genericNameController.text = medicine.genericName ?? '';
      _manufacturerController.text = medicine.manufacturer ?? '';
      _purchasePriceController.text = medicine.purchasePrice?.toString() ?? '';
      _sellingPriceController.text = medicine.sellingPrice.toString();
      _currentStockController.text = medicine.currentStock.toString();
      _reorderLevelController.text = medicine.reorderLevel.toString();
      _batchNumberController.text = medicine.batchNumber ?? '';
      _expiryDateController.text = medicine.expiryDate ?? '';
      
      if (_categories.contains(medicine.category)) {
        _selectedCategory = medicine.category!;
      }
      _requiresPrescription = medicine.requiresPrescription;
      _isActive = medicine.isActive;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectExpiryDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)), // allow past expiry entry for existing stock details
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _expiryDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now().toIso8601String();
    
    // Values
    final name = _nameController.text.trim();
    final genericName = _genericNameController.text.trim();
    final manufacturer = _manufacturerController.text.trim();
    final purchasePrice = double.tryParse(_purchasePriceController.text);
    final sellingPrice = double.parse(_sellingPriceController.text);
    final currentStock = int.parse(_currentStockController.text);
    final reorderLevel = int.tryParse(_reorderLevelController.text) ?? 10;
    final batchNumber = _batchNumberController.text.trim();
    final expiryDate = _expiryDateController.text.trim();

    // Verify uniqueness of name if adding new
    if (!_isEditMode) {
      final allMeds = ref.read(inventoryProvider);
      final isDuplicate = allMeds.any((m) => m.name.toLowerCase() == name.toLowerCase() && m.isActive);
      if (isDuplicate) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Medicine already exists with this name.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    final medicine = Medicine(
      id: _isEditMode ? widget.medicineId! : const Uuid().v4(),
      name: name,
      genericName: genericName.isEmpty ? null : genericName,
      category: _selectedCategory,
      manufacturer: manufacturer.isEmpty ? null : manufacturer,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      currentStock: currentStock,
      reorderLevel: reorderLevel,
      batchNumber: batchNumber.isEmpty ? null : batchNumber,
      expiryDate: expiryDate.isEmpty ? null : expiryDate,
      requiresPrescription: _requiresPrescription,
      isActive: _isActive,
      createdAt: _isEditMode ? null : now, // Database helper updates/creates
      updatedAt: now,
    );

    try {
      if (_isEditMode) {
        await ref.read(inventoryProvider.notifier).updateMedicine(medicine);
      } else {
        await ref.read(inventoryProvider.notifier).addMedicine(medicine);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Medicine saved successfully!')),
        );
        context.go('/inventory');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save. Please try again.'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Navigation Header
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go('/inventory'),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Edit Medicine Details' : 'Add New Medicine',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Form fields card container
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Basic info
                    const Text('Basic Medicine Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Medicine Name *',
                              hintText: 'e.g. Amoxicillin',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Medicine name is required';
                              if (val.trim().length < 2) return 'Must be at least 2 characters';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _genericNameController,
                            decoration: const InputDecoration(
                              labelText: 'Generic Name',
                              hintText: 'e.g. Amoxicillin Trihydrate',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategory,
                            decoration: const InputDecoration(
                              labelText: 'Category *',
                            ),
                            items: _categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Text(cat),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCategory = val;
                                });
                              }
                            },
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Please select a category';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _manufacturerController,
                            decoration: const InputDecoration(
                              labelText: 'Manufacturer',
                              hintText: 'e.g. Pfizer',
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: AppColors.border),
                    ),

                    // Section 2: Pricing and stock
                    const Text('Pricing and Stock Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _purchasePriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Purchase Price (${_isEditMode ? 'Edit' : 'Add'})',
                              hintText: '0.00',
                            ),
                            validator: (val) {
                              if (val != null && val.isNotEmpty) {
                                final p = double.tryParse(val);
                                if (p == null || p < 0) return 'Must be a positive number';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _sellingPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration:  InputDecoration(
                              labelText: 'Selling Price (${_isEditMode ? 'Edit' : 'Add'}) *',
                              hintText: '0.00',
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Selling price is required';
                              final p = double.tryParse(val);
                              if (p == null || p <= 0) return 'Must be greater than 0';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _currentStockController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Current Stock *',
                              hintText: 'e.g. 100',
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Current stock is required';
                              final s = int.tryParse(val);
                              if (s == null || s < 0) return 'Must be 0 or a positive integer';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _reorderLevelController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Reorder Level *',
                              hintText: 'Default 10',
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Reorder level is required';
                              final s = int.tryParse(val);
                              if (s == null || s < 0) return 'Must be 0 or a positive integer';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: AppColors.border),
                    ),

                    // Section 3: Batch and Expiry
                    const Text('Batch and Expiry Tracking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _batchNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Batch Number',
                              hintText: 'e.g. BATCH-1234',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _expiryDateController,
                            readOnly: true,
                            onTap: () => _selectExpiryDate(context),
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date',
                              hintText: 'YYYY-MM-DD',
                              suffixIcon: Icon(Icons.calendar_today, size: 18),
                            ),
                            validator: (val) {
                              if (val != null && val.isNotEmpty && !_isEditMode) {
                                try {
                                  final date = DateTime.parse(val);
                                  if (date.isBefore(DateTime.now())) {
                                    return 'Expiry date must be in the future';
                                  }
                                } catch (_) {
                                  return 'Invalid date format';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Divider(color: AppColors.border),
                    ),

                    // Section 4: Toggles
                    Row(
                      children: [
                        // Requires Prescription Toggle
                        Expanded(
                          child: SwitchListTile(
                            title: const Text(
                              'Requires Prescription',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: const Text('Must present a doctor prescription to dispense'),
                            value: _requiresPrescription,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _requiresPrescription = val;
                              });
                            },
                          ),
                        ),
                        const VerticalDivider(width: 32),
                        // Active/Inactive status toggle
                        Expanded(
                          child: SwitchListTile(
                            title: const Text(
                              'Active Status',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            subtitle: const Text('Inactive medicines are hidden from POS searches'),
                            value: _isActive,
                            activeColor: AppColors.success,
                            onChanged: (val) {
                              setState(() {
                                _isActive = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Form Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => context.go('/inventory'),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _saveForm,
                          child: Text(_isEditMode ? 'Update Medicine' : 'Add Medicine'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
