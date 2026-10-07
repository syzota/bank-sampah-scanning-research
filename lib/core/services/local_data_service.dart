import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'local_database.dart';
import 'local_errors.dart';

/// SQLite-backed data access used by all reconstructed screens.
/// The fluent API keeps existing controllers readable while running local SQL.
class LocalDataService {
  LocalDataService._();
  static final client = LocalClient();
  static LocalUser? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static Future<void> initialize() async {
    await LocalDatabase.instance.open();
    await client.auth.restore();
  }
}

class LocalClient {
  final auth = LocalAuth();
  late final functions = LocalFunctions(auth);
  LocalQuery from(String table) => LocalQuery(table);
  Future<dynamic> rpc(String name, {Map<String, dynamic>? params}) async {
    final response = await functions.invoke(
      name == 'create_pengelola_account' ? 'create-pengelola' : 'delete-pengelola',
      body: (params ?? {}).map((key, value) => MapEntry(key.replaceFirst(RegExp(r'^p_'), ''), value)),
    );
    if (response.status != 200) throw LocalDataException(response.data['error'].toString());
    return response.data;
  }
}

class LocalQuery implements Future<dynamic> {
  final String table;
  String _action = 'select';
  String _projection = '*';
  dynamic _payload;
  final _conditions = <String>[];
  final _arguments = <Object?>[];
  final _orders = <String>[];
  int? _limit;
  bool _single = false;
  bool _optional = false;
  bool _returnRows = false;
  Future<dynamic>? _execution;
  LocalQuery(this.table) { _identifier(table); }

  static const protectedMasters = {
    'kategori_sampah', 'sub_kategori_sampah', 'tipe_sampah',
    'jenis_sampah', 'satuan', 'harga_sampah',
  };
  static String _identifier(String value) {
    if (!RegExp(r'^[a-z_][a-z0-9_]*$').hasMatch(value)) {
      throw const LocalDataException('Nama tabel atau kolom tidak valid.');
    }
    return '"$value"';
  }
  static Object? encode(dynamic value) {
    if (value is bool) return value ? 1 : 0;
    if (value is List || value is Map) return jsonEncode(value);
    return value;
  }
  static Map<String, dynamic> decode(Map<String, Object?> row) {
    final result = Map<String, dynamic>.from(row);
    for (final key in ['is_active', 'is_verified']) {
      if (result.containsKey(key)) result[key] = result[key] == 1;
    }
    if (result['bank_sampah_pilihan'] is String) {
      result['bank_sampah_pilihan'] = jsonDecode(result['bank_sampah_pilihan'] as String);
    }
    return result;
  }

  LocalQuery select([String columns = '*']) {
    _projection = columns;
    if (_action != 'select') _returnRows = true;
    return this;
  }
  LocalQuery insert(dynamic values) { _action = 'insert'; _payload = values; return this; }
  LocalQuery update(Map<String, dynamic> values) { _action = 'update'; _payload = values; return this; }
  LocalQuery delete() { _action = 'delete'; return this; }
  LocalQuery _filter(String column, String op, dynamic value) {
    _conditions.add('${_identifier(column)} $op ?');
    _arguments.add(encode(value));
    return this;
  }
  LocalQuery eq(String column, dynamic value) => value == null
      ? isFilter(column, null) : _filter(column, '=', value);
  LocalQuery gte(String column, dynamic value) => _filter(column, '>=', value);
  LocalQuery lte(String column, dynamic value) => _filter(column, '<=', value);
  LocalQuery isFilter(String column, dynamic value) {
    if (value == null) { _conditions.add('${_identifier(column)} IS NULL'); return this; }
    return eq(column, value);
  }
  LocalQuery inFilter(String column, List<dynamic> values) {
    if (values.isEmpty) { _conditions.add('0 = 1'); return this; }
    _conditions.add('${_identifier(column)} IN (${List.filled(values.length, '?').join(',')})');
    _arguments.addAll(values.map(encode));
    return this;
  }
  LocalQuery order(String column, {bool ascending = true}) {
    _orders.add('${_identifier(column)} ${ascending ? 'ASC' : 'DESC'}');
    return this;
  }
  LocalQuery limit(int count) { _limit = count; return this; }
  LocalQuery single() { _single = true; return this; }
  LocalQuery maybeSingle() { _single = true; _optional = true; return this; }
  String? get _where => _conditions.isEmpty ? null : _conditions.join(' AND ');

  Future<Map<String, Object?>> _prepare(DatabaseExecutor db, Map<dynamic, dynamic> values,
      {Map<String, Object?>? existing}) async {
    final columns = (await db.rawQuery('PRAGMA table_info(${_identifier(table)})'))
        .map((row) => row['name'] as String).toSet();
    final result = <String, Object?>{for (final entry in values.entries) entry.key.toString(): encode(entry.value)};
    if (!columns.containsAll(result.keys)) {
      throw LocalDataException('Kolom tidak dikenal pada $table: ${result.keys.where((key) => !columns.contains(key)).join(', ')}');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    if (existing == null) {
      if (columns.contains('id')) result.putIfAbsent('id', LocalDatabase.newId);
      if (columns.contains('created_at')) result.putIfAbsent('created_at', () => now);
    }
    if (columns.contains('updated_at')) result['updated_at'] = now;
    if (table == 'pengelolaan_sampah') {
      final combined = <String, Object?>{...?existing, ...result};
      result['total_harga'] = (combined['jumlah'] as num).toDouble() *
          ((combined['harga_per_satuan'] as num?)?.toDouble() ?? 0);
    }
    return result;
  }

  Future<dynamic> _run() async {
    final db = LocalDatabase.instance.database;
    List<Map<String, Object?>> rows;
    if (_action != 'select' && protectedMasters.contains(table)) {
      throw const LocalDataException('Master enam kelas dan harga simulasi dikunci selama penelitian.');
    }
    if (_action == 'insert') {
      final payloads = _payload is List ? _payload as List : [_payload];
      final inserted = <String>[];
      await db.transaction((txn) async {
        for (final item in payloads) {
          final values = await _prepare(txn, item as Map);
          await txn.insert(table, values);
          inserted.add(values['id'] as String);
        }
      });
      if (!_returnRows) return null;
      rows = [];
      for (final id in inserted) {
        rows.addAll(await db.query(table, where: 'id = ?', whereArgs: [id]));
      }
    } else if (_action == 'update') {
      rows = await db.query(table, where: _where, whereArgs: _arguments);
      final updated = <Map<String, Object?>>[];
      await db.transaction((txn) async {
        for (final row in rows) {
          final values = await _prepare(txn, _payload as Map, existing: row);
          await txn.update(table, values, where: 'id = ?', whereArgs: [row['id']]);
          updated.add({...row, ...values});
        }
      });
      if (!_returnRows) return null;
      rows = updated;
    } else if (_action == 'delete') {
      await db.delete(table, where: _where, whereArgs: _arguments);
      return null;
    } else {
      rows = await db.query(table, where: _where, whereArgs: _arguments,
          orderBy: _orders.isEmpty ? null : _orders.join(', '), limit: _limit);
    }
    final hydrated = <Map<String, dynamic>>[];
    for (final row in rows) {
      hydrated.add(await _project(db, table, decode(row), _projection));
    }
    if (_single) {
      if (hydrated.isEmpty && _optional) return null;
      if (hydrated.length != 1) throw LocalDataException('Diharapkan satu baris $table, ditemukan ${hydrated.length}.');
      return hydrated.single;
    }
    return hydrated;
  }

  static List<String> _fields(String selection) {
    final result = <String>[];
    var level = 0;
    var start = 0;
    for (var i = 0; i < selection.length; i++) {
      if (selection[i] == '(') level++;
      if (selection[i] == ')') level--;
      if (selection[i] == ',' && level == 0) {
        result.add(selection.substring(start, i).trim()); start = i + 1;
      }
    }
    result.add(selection.substring(start).trim());
    return result.where((field) => field.isNotEmpty).toList();
  }

  static Future<Map<String, dynamic>> _project(DatabaseExecutor db, String table,
      Map<String, dynamic> row, String selection) async {
    final result = <String, dynamic>{};
    for (final field in _fields(selection)) {
      if (field == '*') { result.addAll(row); continue; }
      final open = field.indexOf('(');
      if (open < 0) { result[field] = row[field]; continue; }
      final relation = field.substring(0, open).trim();
      _identifier(relation);
      final foreignKey = switch (relation) {
        'kategori_sampah' => 'kategori_id',
        'sub_kategori_sampah' => 'sub_kategori_id',
        'tipe_sampah' => 'tipe_id',
        'jenis_sampah' => 'jenis_sampah_id',
        'satuan' => table == 'jenis_sampah' ? 'satuan_default_id' : 'satuan_id',
        'bank_sampah' => 'bank_sampah_id',
        'profiles' => 'profile_id',
        _ => throw LocalDataException('Relasi lokal tidak dikenal: $relation'),
      };
      final id = row[foreignKey];
      if (id == null) { result[relation] = null; continue; }
      final related = await db.query(relation, where: 'id = ?', whereArgs: [id], limit: 1);
      result[relation] = related.isEmpty ? null : await _project(
          db, relation, decode(related.single), field.substring(open + 1, field.lastIndexOf(')')));
    }
    return result;
  }

  Future<dynamic> get _future => _execution ??= _run();
  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) => _future.then(onValue, onError: onError);
  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object error)? test}) => _future.catchError(onError, test: test);
  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) => _future.whenComplete(action);
  @override
  Stream<dynamic> asStream() => _future.asStream();
  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) => _future.timeout(timeLimit, onTimeout: onTimeout);
}

class LocalUser {
  final String id;
  final String email;
  const LocalUser(this.id, this.email);
}
class LocalAuthResponse {
  final LocalUser? user;
  const LocalAuthResponse(this.user);
}
class LocalAuth {
  LocalUser? currentUser;
  String _hash(String email, String password) => sha256.convert(utf8.encode('${email.toLowerCase()}:$password')).toString();
  Future<void> restore() async {
    final id = await LocalDatabase.instance.setting('session_user_id');
    if (id == null) return;
    final rows = await LocalDatabase.instance.database.query('auth_users', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) currentUser = LocalUser(id, rows.single['email'] as String);
  }
  Future<LocalAuthResponse> signInWithPassword({required String email, required String password}) async {
    email = email.trim().toLowerCase();
    final rows = await LocalDatabase.instance.database.query('auth_users',
        where: 'email = ? AND password_hash = ?', whereArgs: [email, _hash(email, password)]);
    if (rows.isEmpty) throw const LocalAuthException('Invalid login credentials');
    currentUser = LocalUser(rows.single['id'] as String, email);
    await LocalDatabase.instance.setSetting('session_user_id', currentUser!.id);
    return LocalAuthResponse(currentUser);
  }
  Future<LocalUser> createUser(String email, String password, {DatabaseExecutor? executor}) async {
    email = email.trim().toLowerCase();
    final db = executor ?? LocalDatabase.instance.database;
    if ((await db.query('auth_users', where: 'email = ?', whereArgs: [email])).isNotEmpty) {
      throw const LocalAuthException('User already registered');
    }
    final user = LocalUser(LocalDatabase.newId(), email);
    await db.insert('auth_users', {'id': user.id, 'email': email, 'password_hash': _hash(email, password)});
    return user;
  }
  Future<LocalAuthResponse> signUp({required String email, required String password}) async {
    currentUser = await createUser(email, password);
    await LocalDatabase.instance.setSetting('session_user_id', currentUser!.id);
    return LocalAuthResponse(currentUser);
  }
  Future<void> signOut() async {
    currentUser = null;
    await LocalDatabase.instance.database.delete('app_settings', where: 'key = ?', whereArgs: ['session_user_id']);
  }
  Future<void> resetPasswordForEmail(String email) async {
    throw const LocalAuthException('Versi penelitian memakai akun lokal. Gunakan akun demo pada panduan.');
  }
}

class LocalFunctionResponse {
  final int status;
  final Map<String, dynamic> data;
  const LocalFunctionResponse(this.status, this.data);
}
class LocalFunctions {
  final LocalAuth auth;
  LocalFunctions(this.auth);
  Future<LocalFunctionResponse> invoke(String name, {Map<String, dynamic>? body}) async {
    final values = body ?? {};
    try {
      if (name == 'create-pengelola') {
        return await LocalDatabase.instance.database.transaction((txn) async {
          final user = await auth.createUser(values['email'] as String,
              values['password'] as String, executor: txn);
          final banks = List<String>.from(values['bank_sampah_ids'] as List? ?? []);
          final now = DateTime.now().toUtc().toIso8601String();
          final profile = <String, Object?>{
            'id': LocalDatabase.newId(), 'auth_user_id': user.id,
            'nama_lengkap': values['nama_lengkap'], 'no_hp': values['no_hp'],
            'role': 'pengelola', 'is_verified': banks.isEmpty ? 0 : 1,
            'bank_sampah_pilihan': jsonEncode(banks), 'created_at': now, 'updated_at': now,
          };
          await txn.insert('profiles', profile);
          for (final bank in banks.toSet()) {
            await txn.insert('pengelola_bank_sampah', {
              'id': LocalDatabase.newId(), 'profile_id': profile['id'],
              'bank_sampah_id': bank, 'created_at': now,
            });
          }
          return LocalFunctionResponse(200, {'status': 'success', 'success': true,
            'profile': LocalQuery.decode(profile), 'auth_user_id': user.id});
        });
      }
      if (name == 'delete-pengelola') {
        await LocalDatabase.instance.database.delete('auth_users', where: 'id = ?', whereArgs: [values['auth_user_id']]);
        return const LocalFunctionResponse(200, {'status': 'success', 'success': true});
      }
      throw LocalDataException('Operasi lokal tidak dikenal: $name');
    } catch (error) {
      return LocalFunctionResponse(400, {'error': error.toString()});
    }
  }
}
