import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/medicine_model.dart';
import '../../../core/models/prescription_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../utils/helpers.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _taxController = TextEditingController();

  String? _selectedPrescriptionId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    // Set default discount & tax inputs
    _discountController.text = '0';
    _taxController.text = '5'; // default 5% tax
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _discountController.dispose();
    _taxController.dispose();
    super.dispose();
  }

  void _loadPrescriptionIntoCart(String rxId) async {
    final prescriptions = ref.read(prescriptionProvider);
    final rx = prescriptions.firstWhere((r) => r.id == rxId);
    
    // Clear existing cart first
    final salesNotifier = ref.read(salesProvider.notifier);
    salesNotifier.clearCart();
    
    // Add items
    final availableMeds = ref.read(inventoryProvider);
    try {
      for (final item in rx.items) {
        final med = availableMeds.firstWhere((m) => m.id == item.medicineId);
        salesNotifier.addToCart(med, item.quantity);
      }
      
      // Auto fill customer details from prescription
      _customerNameController.text = rx.patientName;
      _customerPhoneController.text = rx.patientPhone ?? '';
      salesNotifier.setCustomer(rx.patientName, rx.patientPhone ?? '');
      salesNotifier.setPrescriptionId(rx.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Prescription ${rx.prescriptionNumber} loaded into cart.')),
      );
    } catch (e) {
      salesNotifier.clearCart();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient medicine stock to load this prescription.'),
          backgroundColor: AppColors.danger,
        ),
      );
      setState(() {
        _selectedPrescriptionId = null;
      });
    }
  }

  void _showCheckoutDialog(SaleState cartState) {
    if (cartState.cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cart is empty. Add medicines first.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final salesNotifier = ref.read(salesProvider.notifier);
    
    // Set final customer details
    salesNotifier.setCustomer(_customerNameController.text.trim(), _customerPhoneController.text.trim());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CheckoutDialog(
          netTotal: cartState.netTotal,
          customerName: _customerNameController.text,
          onComplete: (paymentMethod, tendered, cardType, policy) async {
            salesNotifier.setPaymentDetails(
              paymentMethod, 
              tendered, 
              cardType: cardType, 
              policyNumber: policy
            );
            
            try {
              final sale = await salesNotifier.processSale();
              Navigator.pop(context); // Close dialog
              
              // Clear fields
              _customerNameController.clear();
              _customerPhoneController.clear();
              _selectedPrescriptionId = null;
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sale processed successfully!')),
              );
              
              // Route to invoice screen
              context.go('/sales/invoice/${sale.id}');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Checkout failed: ${e.toString()}'), backgroundColor: AppColors.danger),
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final allMedicines = ref.watch(inventoryProvider).where((m) => m.isActive).toList();
    final pendingPrescriptions = ref.watch(prescriptionProvider).where((r) => r.status == 'pending').toList();
    final cartState = ref.watch(salesProvider);
    final salesNotifier = ref.read(salesProvider.notifier);

    // Filter medicines by query
    final filteredMedicines = allMedicines.where((med) {
      final q = _searchQuery.toLowerCase();
      return med.name.toLowerCase().contains(q) || (med.genericName ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left Section: Medicine Search List
          Expanded(
            flex: 4,
            child: Container(
              margin: const EdgeInsets.only(left: 24, top: 24, bottom: 24),
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
                    'Available Medicines',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search medicine by name or generic...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(12.0),
                        child: FaIcon(FontAwesomeIcons.magnifyingGlass, size: 14, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredMedicines.isEmpty
                        ? const Center(child: Text('No medicines found.'))
                        : ListView.separated(
                            itemCount: filteredMedicines.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final med = filteredMedicines[index];
                              final isOutOfStock = med.currentStock <= 0;
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            med.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${med.genericName ?? "No Generic"} • Category: ${med.category}',
                                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                          Text(
                                            Helpers.formatCurrency(med.sellingPrice),
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                                          ),
                                        Text(
                                          isOutOfStock ? 'Out of Stock' : 'Stock: ${med.currentStock}',
                                          style: TextStyle(
                                            color: isOutOfStock || med.isLowStock() ? AppColors.danger : AppColors.success,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    ElevatedButton(
                                      onPressed: isOutOfStock
                                          ? null
                                          : () {
                                              try {
                                                salesNotifier.addToCart(med, 1);
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text(e.toString()), backgroundColor: AppColors.danger),
                                                );
                                              }
                                            },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Add', style: TextStyle(fontSize: 12)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Right Section: Cart Checkout details
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.only(right: 24, top: 24, bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('POS Cart', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  const Divider(height: 20),

                  // Link prescription dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedPrescriptionId,
                    decoration: const InputDecoration(
                      labelText: 'Link Pending Prescription',
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('None')),
                      ...pendingPrescriptions.map((rx) {
                        return DropdownMenuItem(
                          value: rx.id,
                          child: Text('${rx.prescriptionNumber} (${rx.patientName})'),
                        );
                      })
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedPrescriptionId = val;
                      });
                      if (val != null) {
                        _loadPrescriptionIntoCart(val);
                      } else {
                        salesNotifier.clearCart();
                        _customerNameController.clear();
                        _customerPhoneController.clear();
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Customer details inputs
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _customerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Customer Name',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _customerPhoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Cart Items list
                  Expanded(
                    child: cartState.cartItems.isEmpty
                        ? const Center(child: Text('Cart is empty. Add medicines from inventory.'))
                        : ListView.separated(
                            itemCount: cartState.cartItems.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final item = cartState.cartItems[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.medicine.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                           Text('${Helpers.formatCurrency(item.unitPrice)} each', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    
                                    // Quantity Selector
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, size: 18, color: AppColors.textSecondary),
                                          onPressed: () {
                                            try {
                                              salesNotifier.updateQuantity(item.medicine.id, item.quantity - 1);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                            }
                                          },
                                        ),
                                        Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.textSecondary),
                                          onPressed: () {
                                            try {
                                              salesNotifier.updateQuantity(item.medicine.id, item.quantity + 1);
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                    
                                    Text(
                                      Helpers.formatCurrency(item.totalPrice),
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                      onPressed: () => salesNotifier.removeFromCart(item.medicine.id),
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
                  ),

                  // Calculations footer
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal:'),
                         Text(Helpers.formatCurrency(cartState.subtotal), style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Text('Discount (%):'),
                      const Spacer(),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _discountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (val) {
                            try {
                              salesNotifier.setDiscount(double.tryParse(val) ?? 0);
                            } catch (_) {}
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('Tax (%):'),
                      const Spacer(),
                      SizedBox(
                        width: 60,
                        child: TextFormField(
                          controller: _taxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.end,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          ),
                          onChanged: (val) {
                            try {
                              salesNotifier.setTax(double.tryParse(val) ?? 0);
                            } catch (_) {}
                          },
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Net Total:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                         Text(Helpers.formatCurrency(cartState.netTotal), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Checkout button
                  ElevatedButton(
                    onPressed: () => _showCheckoutDialog(cartState),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.success,
                    ),
                    child: const Text('Process Sale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

// Checkout Dialog Widget
class CheckoutDialog extends StatefulWidget {
  final double netTotal;
  final String customerName;
  final Function(String paymentMethod, double tendered, String? cardType, String? policy) onComplete;

  const CheckoutDialog({
    super.key,
    required this.netTotal,
    required this.customerName,
    required this.onComplete,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  String _paymentMethod = 'Cash';
  final TextEditingController _tenderedController = TextEditingController();
  final TextEditingController _cardTypeController = TextEditingController();
  final TextEditingController _policyController = TextEditingController();

  double _change = 0.0;

  @override
  void initState() {
    super.initState();
    _tenderedController.text = widget.netTotal.toStringAsFixed(2);
    _tenderedController.addListener(_calculateChange);
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _cardTypeController.dispose();
    _policyController.dispose();
    super.dispose();
  }

  void _calculateChange() {
    final tendered = double.tryParse(_tenderedController.text) ?? 0.0;
    setState(() {
      _change = tendered > widget.netTotal ? tendered - widget.netTotal : 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Process Payment'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(
              'Net Amount: ${Helpers.formatCurrency(widget.netTotal)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
             ),
            const SizedBox(height: 16),
            
            // Payment Method dropdown
            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Payment Method'),
              items: const [
                DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                DropdownMenuItem(value: 'Credit Card', child: Text('Credit Card')),
                DropdownMenuItem(value: 'Debit Card', child: Text('Debit Card')),
                DropdownMenuItem(value: 'Insurance', child: Text('Insurance')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _paymentMethod = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Cash specifics
            if (_paymentMethod == 'Cash') ...[
              TextFormField(
                controller: _tenderedController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Amount Tendered *',
                  prefixText: '',
                ),
                validator: (val) {
                  final t = double.tryParse(val ?? '');
                  if (t == null || t < widget.netTotal) return 'Insufficient tender amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Text(
                'Change Return: ${Helpers.formatCurrency(_change)}',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success),
              ),
            ],

            // Card details
            if (_paymentMethod == 'Credit Card' || _paymentMethod == 'Debit Card') ...[
              TextFormField(
                controller: _cardTypeController,
                decoration: const InputDecoration(
                  labelText: 'Card Provider Name (Optional)',
                  hintText: 'e.g. Visa, Mastercard',
                ),
              ),
            ],

            // Insurance details
            if (_paymentMethod == 'Insurance') ...[
              TextFormField(
                controller: _policyController,
                decoration: const InputDecoration(
                  labelText: 'Policy Number *',
                  hintText: 'e.g. INS-12903-X',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Insurance Policy Number is required';
                  return null;
                },
              ),
              if (widget.customerName.trim().isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                  'Warning: Customer name must be entered in POS details for insurance processing.',
                  style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ]
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            // Validator checks
            final tendered = double.tryParse(_tenderedController.text) ?? 0.0;
            if (_paymentMethod == 'Cash' && tendered < widget.netTotal) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tendered amount must be greater than or equal to total.')),
              );
              return;
            }
            if (_paymentMethod == 'Insurance' && _policyController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Insurance Policy Number is required.')),
              );
              return;
            }

            widget.onComplete(
              _paymentMethod,
              _paymentMethod == 'Cash' ? tendered : widget.netTotal,
              _paymentMethod.contains('Card') ? _cardTypeController.text : null,
              _paymentMethod == 'Insurance' ? _policyController.text : null
            );
          },
          child: const Text('Confirm Payment'),
        ),
      ],
    );
  }
}
