import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseProvider {
  static const String databaseName = 'posture_data.db';
  static const int databaseVersion = 7;
  static const String tableName = 'posture_records';
  static const String summaryTable = 'daily_summaries';
  static const String eodReviewsTable = 'eod_reviews';
  static const String reportsTable = 'daily_reports';

  DatabaseProvider._privateConstructor();
  static final DatabaseProvider instance = DatabaseProvider._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, databaseName);

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT,
        displayName TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE $tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        userId TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        pitchUpper REAL NOT NULL,
        pitchLower REAL NOT NULL,
        deltaPitch REAL NOT NULL,
        postureState INTEGER NOT NULL,
        isVibrating INTEGER NOT NULL,
        stepCount INTEGER NOT NULL,
        sitting INTEGER NOT NULL DEFAULT 0,
        isSynced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE $summaryTable (
        day TEXT NOT NULL,
        userId TEXT NOT NULL,
        totalUprightMs INTEGER NOT NULL DEFAULT 0,
        maxSteps INTEGER NOT NULL DEFAULT 0,
        totalSittingMs INTEGER NOT NULL DEFAULT 0,
        totalStandingMs INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (day, userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE $eodReviewsTable (
        date TEXT NOT NULL,
        userId TEXT NOT NULL,
        energyLevel INTEGER NOT NULL DEFAULT 3,
        painLevel INTEGER NOT NULL DEFAULT 1,
        notes TEXT NOT NULL DEFAULT '',
        createdAt INTEGER NOT NULL,
        isSynced INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (date, userId)
      )
    ''');

    await db.execute('''
      CREATE TABLE $reportsTable (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        date TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {

      await db.execute('''
        CREATE TABLE ${tableName}_new (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          timestamp INTEGER NOT NULL,
          pitchUpper REAL NOT NULL,
          pitchLower REAL NOT NULL,
          deltaPitch REAL NOT NULL DEFAULT 0.0,
          postureState INTEGER NOT NULL DEFAULT 0,
          isVibrating INTEGER NOT NULL DEFAULT 0,
          stepCount INTEGER NOT NULL DEFAULT 0
        )
      ''');

      await db.execute('''
        INSERT INTO ${tableName}_new (timestamp, pitchUpper, pitchLower)
        SELECT timestamp, backAngle, waistAngle FROM $tableName
      ''');

      await db.execute('DROP TABLE $tableName');

      await db.execute('ALTER TABLE ${tableName}_new RENAME TO $tableName');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE $tableName ADD COLUMN isSynced INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE $summaryTable (
          day TEXT PRIMARY KEY,
          totalUprightMs INTEGER NOT NULL DEFAULT 0,
          maxSteps INTEGER NOT NULL DEFAULT 0
        )
      ''');
    }

    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE $tableName ADD COLUMN sitting INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) rethrow;
      }
      try {
        await db.execute('ALTER TABLE $summaryTable ADD COLUMN totalSittingMs INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) rethrow;
      }
      try {
        await db.execute('ALTER TABLE $summaryTable ADD COLUMN totalStandingMs INTEGER NOT NULL DEFAULT 0');
      } catch (e) {
        if (!e.toString().contains('duplicate column name')) rethrow;
      }
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $eodReviewsTable (
          date TEXT PRIMARY KEY,
          energyLevel INTEGER NOT NULL DEFAULT 3,
          painLevel INTEGER NOT NULL DEFAULT 1,
          notes TEXT NOT NULL DEFAULT '',
          createdAt INTEGER NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $reportsTable (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    }

    if (oldVersion < 7) {
      final String currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';

      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          email TEXT,
          displayName TEXT
        )
      ''');

      if (currentUid != 'anonymous') {
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        final displayName = FirebaseAuth.instance.currentUser?.displayName ?? '';
        await db.execute(
          'INSERT OR IGNORE INTO users (id, email, displayName) VALUES (?, ?, ?)',
          [currentUid, email, displayName]
        );
      }

      await db.execute('ALTER TABLE $tableName RENAME TO ${tableName}_old');
      await db.execute('''
        CREATE TABLE $tableName (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          userId TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          pitchUpper REAL NOT NULL,
          pitchLower REAL NOT NULL,
          deltaPitch REAL NOT NULL,
          postureState INTEGER NOT NULL,
          isVibrating INTEGER NOT NULL,
          stepCount INTEGER NOT NULL,
          sitting INTEGER NOT NULL DEFAULT 0,
          isSynced INTEGER NOT NULL DEFAULT 0
        )
      ''');
      await db.execute('''
        INSERT INTO $tableName (id, userId, timestamp, pitchUpper, pitchLower, deltaPitch, postureState, isVibrating, stepCount, sitting, isSynced)
        SELECT id, '$currentUid', timestamp, pitchUpper, pitchLower, deltaPitch, postureState, isVibrating, stepCount, sitting, isSynced FROM ${tableName}_old
      ''');
      await db.execute('DROP TABLE ${tableName}_old');

      await db.execute('ALTER TABLE $summaryTable RENAME TO ${summaryTable}_old');
      await db.execute('''
        CREATE TABLE $summaryTable (
          day TEXT NOT NULL,
          userId TEXT NOT NULL,
          totalUprightMs INTEGER NOT NULL DEFAULT 0,
          maxSteps INTEGER NOT NULL DEFAULT 0,
          totalSittingMs INTEGER NOT NULL DEFAULT 0,
          totalStandingMs INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (day, userId)
        )
      ''');
      await db.execute('''
        INSERT INTO $summaryTable (day, userId, totalUprightMs, maxSteps, totalSittingMs, totalStandingMs)
        SELECT day, '$currentUid', totalUprightMs, maxSteps, totalSittingMs, totalStandingMs FROM ${summaryTable}_old
      ''');
      await db.execute('DROP TABLE ${summaryTable}_old');

      await db.execute('ALTER TABLE $eodReviewsTable RENAME TO ${eodReviewsTable}_old');
      await db.execute('''
        CREATE TABLE $eodReviewsTable (
          date TEXT NOT NULL,
          userId TEXT NOT NULL,
          energyLevel INTEGER NOT NULL DEFAULT 3,
          painLevel INTEGER NOT NULL DEFAULT 1,
          notes TEXT NOT NULL DEFAULT '',
          createdAt INTEGER NOT NULL,
          isSynced INTEGER NOT NULL DEFAULT 0,
          PRIMARY KEY (date, userId)
        )
      ''');
      await db.execute('''
        INSERT INTO $eodReviewsTable (date, userId, energyLevel, painLevel, notes, createdAt, isSynced)
        SELECT date, '$currentUid', energyLevel, painLevel, notes, createdAt, isSynced FROM ${eodReviewsTable}_old
      ''');
      await db.execute('DROP TABLE ${eodReviewsTable}_old');

      await db.execute('ALTER TABLE $reportsTable RENAME TO ${reportsTable}_old');
      await db.execute('''
        CREATE TABLE $reportsTable (
          id TEXT PRIMARY KEY,
          userId TEXT NOT NULL,
          date TEXT NOT NULL,
          content TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        INSERT INTO $reportsTable (id, userId, date, content, createdAt)
        SELECT id, '$currentUid', date, content, createdAt FROM ${reportsTable}_old
      ''');
      await db.execute('DROP TABLE ${reportsTable}_old');
    }
  }
}
