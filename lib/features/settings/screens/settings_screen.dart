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
