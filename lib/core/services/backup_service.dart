import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database_helper.dart';

class BackupService {
  static Future<File> backupDatabase({String? customDestinationDir}) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFile = File(join(docsDir.path, 'pharmacy_system', 'pharmacy.db'));

    if (!await dbFile.exists()) {
      throw Exception('Database file does not exist to backup.');
    }

    final backupDir = Directory(customDestinationDir ?? join(docsDir.path, 'pharmacy_system', 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final backupFile = File(join(backupDir.path, 'pharmacy_backup_$dateStr.db'));

    // Ensure database writes are flushed
    final db = await DatabaseHelper.instance.database;
    await db.execute('PRAGMA wal_checkpoint(FULL)');

    await dbFile.copy(backupFile.path);
    return backupFile;
  }

  static Future<void> restoreDatabase(File backupFile) async {
    if (!await backupFile.exists()) {
      throw Exception('Selected backup file does not exist.');
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final dbFile = File(join(docsDir.path, 'pharmacy_system', 'pharmacy.db'));

    // Close active database instance
    await DatabaseHelper.instance.close();

    // Copy backup over active database
    await backupFile.copy(dbFile.path);

    // Re-initialize database instance
    await DatabaseHelper.instance.database;
  }

  static Future<List<File>> getBackupFiles() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(join(docsDir.path, 'pharmacy_system', 'backups'));
    
    if (!await backupDir.exists()) return [];

    final list = backupDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.db'))
        .toList();

    list.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return list;
  }

  static Future<void> autoBackupOnSchedule() async {
    try {
      final backups = await getBackupFiles();
      final todayStr = DateFormat('yyyyMMdd').format(DateTime.now());

      bool hasTodayBackup = backups.any((f) {
        final basename = f.path.split(Platform.pathSeparator).last;
        return basename.contains(todayStr);
      });

      if (!hasTodayBackup) {
        await backupDatabase();
      }
    } catch (_) {
      // Background auto backup fail safe
    }
  }
}
