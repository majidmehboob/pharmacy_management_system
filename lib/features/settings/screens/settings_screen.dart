import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme.dart';
import '../../../app/providers.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/services/backup_service.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  List<File> _backups = [];
  List<ActivityLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final backups = await BackupService.getBackupFiles();
      final db = ref.read(databaseHelperProvider);
      final logs = await db.getActivityLogs(limit: 20);

      if (mounted) {
        setState(() {
          _backups = backups;
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _triggerBackup() async {
    try {
      final backupFile = await BackupService.backupDatabase();
      final currentUser = ref.read(authProvider).user;
      final db = ref.read(databaseHelperProvider);
      await db.logActivity(currentUser?.name ?? 'Admin', currentUser?.role ?? 'Admin', 'Database Backup', details: 'Backup created: ${backupFile.path}');

      await _loadSettingsData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup created: ${backupFile.path.split(Platform.pathSeparator).last}'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: ${e.toString()}'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _confirmRestore(File backupFile) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Restore Database'),
          content: Text('Are you sure you want to restore from ${backupFile.path.split(Platform.pathSeparator).last}? Current database state will be replaced.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                try {
                  await BackupService.restoreDatabase(backupFile);
                  await ref.read(inventoryProvider.notifier).loadMedicines();
                  await ref.read(prescriptionProvider.notifier).loadPrescriptions();
                  await _loadSettingsData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Database restored successfully!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Restore failed: ${e.toString()}'), backgroundColor: AppColors.danger),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Restore Database'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isAdmin = user?.role == 'Admin';
    final printerState = ref.watch(printerProvider);

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'System Settings & Operations',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                if (isAdmin)
                  ElevatedButton.icon(
                    onPressed: () => context.go('/users'),
                    icon: const FaIcon(FontAwesomeIcons.usersGear, size: 14),
                    label: const Text('User Management'),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Backup & Restore Card
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Database Backup & Restore', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          SizedBox(height: 4),
                          Text('Create offline database backups or restore from an existing file.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: _triggerBackup,
                        icon: const FaIcon(FontAwesomeIcons.floppyDisk, size: 14),
                        label: const Text('Create Backup Now'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  const Text('Available Backup Files:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  _backups.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No backup files found yet. Click "Create Backup Now" to create one.', style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _backups.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final file = _backups[index];
                            final fileName = file.path.split(Platform.pathSeparator).last;
                            final stat = file.statSync();
                            final modDate = DateFormat('yyyy-MM-dd hh:mm a').format(stat.modified);
                            final sizeKB = (stat.size / 1024).toStringAsFixed(1);

                            return ListTile(
                              leading: const FaIcon(FontAwesomeIcons.database, color: AppColors.primary, size: 20),
                              title: Text(fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text('Created: $modDate • Size: $sizeKB KB'),
                              trailing: OutlinedButton(
                                onPressed: isAdmin ? () => _confirmRestore(file) : null,
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.danger)),
                                child: const Text('Restore', style: TextStyle(color: AppColors.danger)),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Printer Configuration Card
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
                  const Row(
                    children: [
                      FaIcon(FontAwesomeIcons.print, color: AppColors.primary, size: 20),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Thermal Printer Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          SizedBox(height: 4),
                          Text('Configure receipt printer settings for POS checkout.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Connection Type Selector
                  Row(
                    children: [
                      const Text('Connection Type:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: printerState.connectionType,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: const [
                            DropdownMenuItem(value: 'None', child: Text('Disabled')),
                            DropdownMenuItem(value: 'USB', child: Text('USB (Thermal Printer)')),
                            DropdownMenuItem(value: 'BLE', child: Text('Bluetooth (BLE)')),
                            DropdownMenuItem(value: 'Network', child: Text('Network (Ethernet/Wi-Fi)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(printerProvider.notifier).saveSettings(
                                connectionType: val,
                                name: '',
                                address: '',
                                port: printerState.port,
                                paperSize: printerState.paperSize,
                                autoPrint: printerState.autoPrint,
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // If USB or BLE chosen, show scanning controls and scanned list
                  if (printerState.connectionType == 'USB' || printerState.connectionType == 'BLE') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Configured: ${printerState.name.isEmpty ? "None" : printerState.name} (${printerState.address})', 
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: printerState.isScanning 
                              ? null 
                              : () => ref.read(printerProvider.notifier).startScan(),
                          icon: printerState.isScanning 
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const FaIcon(FontAwesomeIcons.magnifyingGlass, size: 12),
                          label: Text(printerState.isScanning ? 'Scanning...' : 'Scan'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (printerState.scannedPrinters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(printerState.isScanning ? 'Looking for devices...' : 'No printers found yet. Connect your device and click Scan.', 
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                      )
                    else
                      Container(
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView.builder(
                          itemCount: printerState.scannedPrinters.length,
                          itemBuilder: (context, index) {
                            final device = printerState.scannedPrinters[index];
                            final isCurrent = printerState.address == device.address;
                            return ListTile(
                              dense: true,
                              title: Text(device.name ?? 'Unknown Device'),
                              subtitle: Text(device.address ?? ''),
                              trailing: isCurrent 
                                  ? const Icon(Icons.check_circle, color: AppColors.success, size: 18)
                                  : OutlinedButton(
                                      onPressed: () {
                                        ref.read(printerProvider.notifier).saveSettings(
                                          connectionType: printerState.connectionType,
                                          name: device.name ?? 'Unknown Device',
                                          address: device.address ?? '',
                                          port: printerState.port,
                                          paperSize: printerState.paperSize,
                                          autoPrint: printerState.autoPrint,
                                        );
                                      },
                                      child: const Text('Select'),
                                    ),
                            );
                          },
                        ),
                      ),
                  ],

                  // If Network chosen, show IP Address and Port input fields
                  if (printerState.connectionType == 'Network') ...[
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            key: ValueKey('ip_address_${printerState.address}'),
                            initialValue: printerState.address,
                            decoration: const InputDecoration(
                              labelText: 'Printer IP Address *',
                              hintText: 'e.g. 192.168.1.100',
                            ),
                            onChanged: (val) {
                              ref.read(printerProvider.notifier).saveSettings(
                                connectionType: printerState.connectionType,
                                name: 'Network Printer',
                                address: val.trim(),
                                port: printerState.port,
                                paperSize: printerState.paperSize,
                                autoPrint: printerState.autoPrint,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            key: ValueKey('port_${printerState.port}'),
                            initialValue: printerState.port.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Port *',
                            ),
                            onChanged: (val) {
                              final portNum = int.tryParse(val) ?? 9100;
                              ref.read(printerProvider.notifier).saveSettings(
                                connectionType: printerState.connectionType,
                                name: printerState.name,
                                address: printerState.address,
                                port: portNum,
                                paperSize: printerState.paperSize,
                                autoPrint: printerState.autoPrint,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // Paper Size and Auto Print Preferences
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Paper Size (58mm vs 80mm)
                      Row(
                        children: [
                          const Text('Paper Width: ', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('58 mm'),
                            selected: printerState.paperSize == 58,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(printerProvider.notifier).saveSettings(
                                  connectionType: printerState.connectionType,
                                  name: printerState.name,
                                  address: printerState.address,
                                  port: printerState.port,
                                  paperSize: 58,
                                  autoPrint: printerState.autoPrint,
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('80 mm'),
                            selected: printerState.paperSize == 80,
                            onSelected: (selected) {
                              if (selected) {
                                ref.read(printerProvider.notifier).saveSettings(
                                  connectionType: printerState.connectionType,
                                  name: printerState.name,
                                  address: printerState.address,
                                  port: printerState.port,
                                  paperSize: 80,
                                  autoPrint: printerState.autoPrint,
                                );
                              }
                            },
                          ),
                        ],
                      ),

                      // Auto Print Receipt toggle
                      Row(
                        children: [
                          const Text('Auto-Print on Checkout:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          Switch(
                            value: printerState.autoPrint,
                            onChanged: (val) {
                              ref.read(printerProvider.notifier).saveSettings(
                                connectionType: printerState.connectionType,
                                name: printerState.name,
                                address: printerState.address,
                                port: printerState.port,
                                paperSize: printerState.paperSize,
                                autoPrint: val,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Display errors if any
                  if (printerState.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      printerState.error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Activity Logs Section
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
                  const Text('Recent System Activity Logs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const Divider(height: 24),
                  _logs.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('No activity logs recorded yet.', style: TextStyle(color: AppColors.textSecondary)),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _logs.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final log = _logs[index];
                            final date = DateTime.tryParse(log.timestamp) ?? DateTime.now();
                            final timeStr = DateFormat('MMM d, hh:mm a').format(date);

                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.background,
                                    child: Text(log.userName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${log.userName} (${log.userRole}): ${log.action}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        if (log.details != null)
                                          Text(log.details!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Text(timeStr, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
