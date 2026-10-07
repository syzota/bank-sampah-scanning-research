import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../config/research_config.dart';

class LocalDatabase {
  LocalDatabase._();
  static final instance = LocalDatabase._();
  Database? _database;
  Database get database => _database ?? (throw StateError('Database belum dibuka.'));

  /// Allows meaningful SQL/controller tests to use an in-memory database.
  void useDatabaseForTesting(Database database) { _database = database; }

  static String newId() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> open() async {
    if (_database != null) return;
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final folder = await getApplicationSupportDirectory();
    await folder.create(recursive: true);
    _database = await openDatabase(
      p.join(folder.path, 'bisa_research_${ResearchConfig.model.name}.db'),
      version: ResearchConfig.schemaVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final schema = await rootBundle.loadString('assets/data/schema.sql');
        for (final statement in schema.split(';')) {
          if (statement.trim().isNotEmpty) await db.execute(statement);
        }
        final raw = jsonDecode(await rootBundle.loadString('assets/data/seed.json')) as Map<String, dynamic>;
        // JSON object order is the foreign-key insertion order.
        for (final entry in raw.entries) {
          for (final row in entry.value as List) {
            await db.insert(entry.key, Map<String, Object?>.from(row as Map));
          }
        }
        await db.insert('app_settings', {'key': 'device_id', 'value': newId()});
        await db.insert('app_settings', {'key': 'seed_version', 'value': ResearchConfig.seedVersion});
      },
    );
  }

  Future<String?> setting(String key) async {
    final rows = await database.query('app_settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.single['value'] as String;
  }

  Future<void> setSetting(String key, String value) => database.insert(
        'app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      ).then((_) {});
}
