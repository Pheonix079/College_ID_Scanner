import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/student.dart';

class DBHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String dbPath;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      dbPath = join(docsDir.path, 'students.db');
    } else {
      dbPath = join(
        await getDatabasesPath(),
        'students.db',
      );
    }

    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE students(
            roll TEXT PRIMARY KEY,
            name TEXT,
            year TEXT,
            branch TEXT,
            bus_paid INTEGER,
            bus_route_no TEXT,
            photo_path TEXT,
            photo_url TEXT
          )
        ''');

        await db.execute('''
          CREATE INDEX idx_students_roll
          ON students(roll)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE students '
            'ADD COLUMN photo_url TEXT',
          );

          await db.execute('''
            CREATE INDEX IF NOT EXISTS
            idx_students_roll
            ON students(roll)
          ''');
        }
      },
    );

    return _db!;
  }

  static Future<void> insert(Student student) async {
    final dbClient = await db;

    await dbClient.insert(
      'students',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> batchInsert(
    List<Student> students,
  ) async {
    final dbClient = await db;

    await dbClient.transaction((txn) async {
      await txn.delete('students');

      final batch = txn.batch();

      for (final student in students) {
        batch.insert(
          'students',
          student.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
    });
  }

  static Future<Student?> getStudent(
    String roll,
  ) async {
    final dbClient = await db;

    final result = await dbClient.query(
      'students',
      where: 'roll = ?',
      whereArgs: [roll],
      limit: 1,
    );

    if (result.isEmpty) return null;

    return Student.fromMap(result.first);
  }

  static Future<List<Student>> getAllStudents() async {
    final dbClient = await db;

    final result = await dbClient.query(
      'students',
      orderBy: 'roll ASC',
    );

    return result.map(Student.fromMap).toList();
  }

  static Future<int> getStudentCount() async {
    final dbClient = await db;

    final result = await dbClient.rawQuery(
      'SELECT COUNT(*) as count FROM students',
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> updateStudent(
    Student student,
  ) async {
    final dbClient = await db;

    await dbClient.update(
      'students',
      student.toMap(),
      where: 'roll = ?',
      whereArgs: [student.roll],
    );
  }

  static Future<void> clearTable() async {
    final dbClient = await db;
    await dbClient.delete('students');
  }

  static Future<void> close() async {
    final dbClient = _db;
    if (dbClient != null) {
      await dbClient.close();
      _db = null;
    }
  }
}
