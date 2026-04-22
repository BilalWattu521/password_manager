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
      version: 2,
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
        await db.execute('CREATE INDEX idx_app_name ON credentials (appName)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'CREATE INDEX idx_app_name ON credentials (appName)',
          );
        }
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

  Future<List<Map<String, dynamic>>> getAppsWithCounts() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT appName, COUNT(*) as count 
      FROM credentials 
      GROUP BY appName 
      ORDER BY appName ASC
    ''');
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

  /// Fetch every credential row for export.
  Future<List<Map<String, dynamic>>> getAllCredentials() async {
    final db = await database;
    return await db.query('credentials', orderBy: 'appName ASC, createdAt ASC');
  }

  /// Batch-insert credentials from an import, skipping exact duplicates.
  Future<void> importCredentials(
    List<Map<String, dynamic>> rows,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      for (final row in rows) {
        // Avoid inserting an exact duplicate (same app + username + password)
        final existing = await txn.query(
          'credentials',
          where: 'appName = ? AND username = ? AND password = ?',
          whereArgs: [row['appName'], row['username'], row['password']],
          limit: 1,
        );
        if (existing.isEmpty) {
          await txn.insert('credentials', {
            'appName': row['appName'],
            'username': row['username'],
            'password': row['password'],
            'createdAt':
                row['createdAt'] ?? DateTime.now().toIso8601String(),
          });
        }
      }
    });
  }
}
