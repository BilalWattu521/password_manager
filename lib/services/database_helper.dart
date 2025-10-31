import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Database helper
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'password_manager.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE credentials (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            appName TEXT NOT NULL,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            createdAt TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> addCredential({
    required String appName,
    required String username,
    required String password,
  }) async {
    final db = await database;
    return await db.insert('credentials', {
      'appName': appName,
      'username': username,
      'password': password,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<String>> getAllApps() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT DISTINCT appName FROM credentials ORDER BY appName ASC',
    );
    return result.map((row) => row['appName'] as String).toList();
  }

  Future<List<Map<String, dynamic>>> getCredentialsForApp(
    String appName,
  ) async {
    final db = await database;
    return await db.query(
      'credentials',
      where: 'appName = ?',
      whereArgs: [appName],
      orderBy: 'createdAt DESC',
    );
  }

  Future<int> updateCredential({
    required int id,
    required String username,
    required String password,
  }) async {
    final db = await database;
    return await db.update(
      'credentials',
      {'username': username, 'password': password},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCredential(int id) async {
    final db = await database;
    return await db.delete('credentials', where: 'id = ?', whereArgs: [id]);
  }
}
