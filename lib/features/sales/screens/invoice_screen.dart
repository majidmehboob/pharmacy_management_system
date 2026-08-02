import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/models/sale_model.dart';
import '../../../utils/helpers.dart';

class InvoiceScreen extends ConsumerStatefulWidget {
  final String saleId;
  const InvoiceScreen({super.key, required this.saleId});

  @override
  ConsumerState<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends ConsumerState<InvoiceScreen> {
  bool _isLoading = true;
  Sale? _sale;

  @override
  void initState() {
    super.initState();
    _loadSale();
  }

  Future<void> _loadSale() async {
    final notifier = ref.read(salesProvider.notifier);
    final sale = await notifier.getSaleById(widget.saleId);
    if (mounted) {
      setState(() {
        _sale = sale;
        _isLoading = false;
      });

      // Auto-print if enabled in settings
      final printerState = ref.read(printerProvider);
      if (printerState.autoPrint && printerState.connectionType != 'None' && sale != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handlePrint();
        });
      }
    }
  }

  void _handlePrint() async {
    if (_sale == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecting to printer and sending data...')),
    );

    final success = await ref.read(printerProvider.notifier).printReceipt(_sale!);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt printed successfully!'), backgroundColor: AppColors.success),
        );
      } else {
        final err = ref.read(printerProvider).error ?? 'Unknown error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Printing failed: $err'), backgroundColor: AppColors.danger),
        );
      }
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

    if (_sale == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Invoice not found.'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/sales/history'),
                child: const Text('Back to Sales History'),
              )
            ],
          ),
        ),
      );
    }

    final sale = _sale!;
    final date = DateTime.tryParse(sale.saleDate) ?? DateTime.now();
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy • hh:mm a').format(date);
    
    // Calculate values
    final discountVal = sale.totalAmount * (sale.discount / 100);
    final taxVal = (sale.totalAmount - discountVal) * (sale.tax / 100);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: EdgeInsets.all(AppTheme.sectionPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header options
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.go('/sales/history'),
                ),
                const SizedBox(width: 8),
                Text(
                  'Invoice Receipt: ${sale.invoiceNumber}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _handlePrint,
                  icon: const FaIcon(FontAwesomeIcons.print, size: 14),
                  label: const Text('Print Receipt'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => context.go('/sales/pos'),
                  icon: const FaIcon(FontAwesomeIcons.cashRegister, size: 14),
                  label: const Text('New Sale (POS)'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Print Preview Card
            Expanded(
              child: Center(
                child: Container(
                  width: 600,
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Pharmacy Header
                      const Center(
                        child: Text(
                          'COMMUNITY HEALTH PHARMACY',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1.2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text(
                          '123 Medical Avenue, Healthcare City\nPhone: (123) 456-7890 • Support: contact@pharmacy.com',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: DottedLine(),
                      ),

                      // Customer / Invoice Details
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('INVOICE TO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                              const SizedBox(height: 4),
                              Text(sale.customerName ?? 'Walk-in Customer', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              if (sale.customerPhone != null && sale.customerPhone!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text('Phone: ${sale.customerPhone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('INVOICE NO: ${sale.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                              const SizedBox(height: 4),
                              Text(formattedDate, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),

                      // Column headings
                      Row(
                        children: const [
                          Expanded(flex: 3, child: Text('Medicine Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary))),
                          Expanded(flex: 1, child: Text('Qty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center)),
                          Expanded(flex: 1, child: Text('Unit Price', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.end)),
                          Expanded(flex: 1, child: Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.end)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(color: AppColors.border),

                      // Items list
                      Expanded(
                        child: ListView.builder(
                          itemCount: sale.items.length,
                          itemBuilder: (context, index) {
                            final item = sale.items[index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.medicine?.name ?? 'Unknown Medicine', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (item.medicine?.genericName != null)
                                          Text(item.medicine!.genericName!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(item.quantity.toString(), textAlign: TextAlign.center),
                                  ),
                                  Expanded(
                                    flex: 1,
                                     child: Text(Helpers.formatCurrency(item.unitPrice), textAlign: TextAlign.end),
                                  ),
                                  Expanded(
                                    flex: 1,
                                     child: Text(Helpers.formatCurrency(item.totalPrice), textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),

                      // Receipt calculation Summary
                       _buildSummaryRow('Subtotal:', Helpers.formatCurrency(sale.totalAmount)),
                       _buildSummaryRow('Discount (${sale.discount.toStringAsFixed(0)}%):', '-${Helpers.formatCurrency(discountVal)}'),
                       _buildSummaryRow('Tax (${sale.tax.toStringAsFixed(0)}%):', '+${Helpers.formatCurrency(taxVal)}'),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: DottedLine(),
                      ),
                      _buildSummaryRow(
                        'Net Total:', 
                        Helpers.formatCurrency(sale.netAmount), 
                        isBold: true,
                        fontSize: 16,
                        textColor: AppColors.primary
                      ),
                      _buildSummaryRow('Payment Method:', sale.paymentMethod),
                      if (sale.status == 'refunded') ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'TRANSACTION REFUNDED',
                            style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        )
                      ],
                      const SizedBox(height: 24),
                      const Center(
                        child: Text(
                          'Thank you for visiting! Get well soon.',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: fontSize,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// Simple custom painter for receipt dotted divider line
class DottedLine extends StatelessWidget {
  const DottedLine({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DottedLinePainter(),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    
    const double dashWidth = 5;
    const double dashSpace = 3;
    double startX = 0;
    
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
