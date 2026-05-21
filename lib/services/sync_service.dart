import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_helper.dart';
import '../models/student.dart';

typedef SyncProgressCallback = void Function(String message);

// ---------------------------------------------------------------------------
// Statistics returned after a photo sync run
// ---------------------------------------------------------------------------
class PhotoSyncStats {
  final int total;
  final int checked;
  final int downloaded;
  final int skipped;
  final int failed;

  const PhotoSyncStats({
    required this.total,
    required this.checked,
    required this.downloaded,
    required this.skipped,
    required this.failed,
  });
}

// ---------------------------------------------------------------------------
// Background sync state — observable from anywhere in the app
// ---------------------------------------------------------------------------
class SyncState {
  final bool dataSyncRunning;
  final bool photoSyncRunning;
  final String dataMessage;
  final String photoMessage;
  final PhotoSyncStats? lastPhotoStats;

  const SyncState({
    this.dataSyncRunning = false,
    this.photoSyncRunning = false,
    this.dataMessage = '',
    this.photoMessage = '',
    this.lastPhotoStats,
  });

  SyncState copyWith({
    bool? dataSyncRunning,
    bool? photoSyncRunning,
    String? dataMessage,
    String? photoMessage,
    PhotoSyncStats? lastPhotoStats,
  }) =>
      SyncState(
        dataSyncRunning: dataSyncRunning ?? this.dataSyncRunning,
        photoSyncRunning: photoSyncRunning ?? this.photoSyncRunning,
        dataMessage: dataMessage ?? this.dataMessage,
        photoMessage: photoMessage ?? this.photoMessage,
        lastPhotoStats: lastPhotoStats ?? this.lastPhotoStats,
      );
}

// ---------------------------------------------------------------------------
// Main service
// ---------------------------------------------------------------------------
class SyncService {
  // ── Concurrency ────────────────────────────────────────────────────────────
  static const int _concurrency = 100; // 100 simultaneous photo downloads
  static const int _headConcurrency = 100; // 100 simultaneous HEAD checks
  static const int _maxRetries = 3;

  // ── SharedPreferences keys ─────────────────────────────────────────────────
  static const String _kInProgress = 'photo_sync_in_progress';
  static const String _kCompletedRolls = 'photo_sync_completed_rolls';
  static const String _kTotal = 'photo_sync_total';
  static const String _kChecked = 'photo_sync_checked';
  static const String _kDownloaded = 'photo_sync_downloaded';
  static const String _kFailed = 'photo_sync_failed';

  // ── Background state stream ────────────────────────────────────────────────
  static final StreamController<SyncState> _stateController =
      StreamController<SyncState>.broadcast();

  static Stream<SyncState> get stateStream => _stateController.stream;

  static SyncState _state = const SyncState();
  static SyncState get currentState => _state;

  static void _emit(SyncState next) {
    _state = next;
    if (!_stateController.isClosed) _stateController.add(next);
  }

  // ── HTTP client ────────────────────────────────────────────────────────────
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      followRedirects: true,
    ),
  );

  // ── Header aliases ─────────────────────────────────────────────────────────
  static const List<List<String>> _headerAliases = [
    ['roll', 'roll_number', 'rollno', 'roll_no'],
    ['name', 'student_name'],
    ['year'],
    ['branch'],
    ['bus_paid', 'buspaid'],
    ['bus_route_no', 'bus_route', 'busrouteno', 'route'],
    ['photo_url', 'photos', 'photo', 'image_url', 'image'],
  ];

  // ===========================================================================
  // DATA SYNC — background, atomic
  // ===========================================================================

  /// Starts data sync in the background. Returns immediately.
  /// Progress is broadcast on [stateStream].
  /// Optionally also calls [onProgress] for backwards-compat.
  static Future<void> syncStudentData({
    SyncProgressCallback? onProgress,
  }) async {
    if (_state.dataSyncRunning) return; // already running

    void report(String msg) {
      onProgress?.call(msg);
      _emit(_state.copyWith(dataSyncRunning: true, dataMessage: msg));
    }

    _emit(_state.copyWith(dataSyncRunning: true, dataMessage: 'Starting...'));

    // Run entirely in background — caller does NOT await the inner work.
    _runDataSync(report).then((_) {
      _emit(_state.copyWith(dataSyncRunning: false, dataMessage: 'Done'));
    }).catchError((e) {
      _emit(_state.copyWith(
          dataSyncRunning: false, dataMessage: 'Failed: $e'));
    });
  }

  static Future<void> _runDataSync(void Function(String) report) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      report('Downloading CSV...');

      final rawUrl = prefs.getString('data_url');
      if (rawUrl == null || rawUrl.trim().isEmpty) {
        throw Exception(
            'No CSV URL configured. Please set it in the Admin Panel.');
      }

      final csvUrl = _buildCsvUrl(rawUrl.trim());
      final response = await http
          .get(Uri.parse(csvUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
            'Download failed (HTTP ${response.statusCode}). '
            'Ensure the sheet is published to the web.');
      }

      report('Parsing CSV...');

      final csvString = utf8.decode(response.bodyBytes);
      final rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(csvString);

      if (rows.isEmpty) throw Exception('Downloaded CSV is empty.');

      final nonEmpty = rows
          .where((r) => r.any((c) => c.toString().trim().isNotEmpty))
          .toList();

      if (nonEmpty.length <= 1) {
        throw Exception('CSV has no data rows (only a header was found).');
      }

      _validateHeaders(nonEmpty.first);

      report('Preparing ${nonEmpty.length - 1} records...');

      final photoDir = await _getPhotoDirectory();
      final List<Student> students = [];

      for (int i = 1; i < nonEmpty.length; i++) {
        final row = nonEmpty[i];
        if (row.isEmpty) continue;
        final roll = row[0].toString().trim();
        if (roll.isEmpty) continue;

        final photoUrl = row.length > 6 ? row[6].toString().trim() : '';
        final photoPath =
            photoUrl.isNotEmpty ? '${photoDir.path}/$roll.jpg' : '';

        students.add(Student(
          roll: roll,
          name: row.length > 1 ? row[1].toString().trim() : '',
          year: row.length > 2 ? row[2].toString().trim() : '',
          branch: row.length > 3 ? row[3].toString().trim() : '',
          busPaid: row.length > 4 && row[4].toString().trim() == '1',
          busRouteNo: row.length > 5 ? row[5].toString().trim() : '',
          photoPath: photoPath,
          photoUrl: photoUrl,
        ));
      }

      report('Saving ${students.length} records...');
      await DBHelper.batchInsert(students);

      await _saveStatus(
          'data_sync_status', 'Success: ${students.length} records');
      report('Done — ${students.length} records synced.');
    } catch (e) {
      await _saveStatus('data_sync_status', 'Failed: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // PHOTO SYNC — background, resumable, 100-concurrent, atomic per file
  // ===========================================================================

  /// Starts photo sync in the background. Returns immediately.
  /// Progress is broadcast on [stateStream].
  static Future<PhotoSyncStats> syncPhotos({
    SyncProgressCallback? onProgress,
  }) async {
    if (_state.photoSyncRunning) {
      return const PhotoSyncStats(
          total: 0, checked: 0, downloaded: 0, skipped: 0, failed: 0);
    }

    void report(String msg) {
      onProgress?.call(msg);
      _emit(_state.copyWith(photoSyncRunning: true, photoMessage: msg));
    }

    _emit(_state.copyWith(
        photoSyncRunning: true, photoMessage: 'Starting...'));

    // Run in background — this future resolves when sync finishes.
    return _runPhotoSync(report).then((stats) {
      _emit(_state.copyWith(
        photoSyncRunning: false,
        photoMessage:
            '↓${stats.downloaded}  ✓${stats.skipped}  ✗${stats.failed}',
        lastPhotoStats: stats,
      ));
      return stats;
    }).catchError((e) {
      _emit(_state.copyWith(
          photoSyncRunning: false, photoMessage: 'Failed: $e'));
      return PhotoSyncStats(
          total: 0, checked: 0, downloaded: 0, skipped: 0, failed: 0);
    });
  }

  static Future<PhotoSyncStats> _runPhotoSync(
      void Function(String) report) async {
    final prefs = await SharedPreferences.getInstance();

    int checked = 0;
    int downloaded = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final students = await DBHelper.getAllStudents();
      final withPhotos =
          students.where((s) => s.photoUrl.isNotEmpty).toList();

      if (withPhotos.isEmpty) {
        report('No photos to sync.');
        await _saveStatus('photo_sync_status', 'Success: no photos to sync');
        await _clearPhotoSyncState(prefs);
        return const PhotoSyncStats(
            total: 0, checked: 0, downloaded: 0, skipped: 0, failed: 0);
      }

      // ── Resume ─────────────────────────────────────────────────────────
      final wasInProgress = prefs.getBool(_kInProgress) ?? false;
      final completedRolls = wasInProgress
          ? Set<String>.from(prefs.getStringList(_kCompletedRolls) ?? [])
          : <String>{};

      if (wasInProgress && completedRolls.isNotEmpty) {
        checked = prefs.getInt(_kChecked) ?? 0;
        downloaded = prefs.getInt(_kDownloaded) ?? 0;
        report('Resuming — ${completedRolls.length} done, '
            '${withPhotos.length - completedRolls.length} remaining...');
      }

      await prefs.setBool(_kInProgress, true);
      await prefs.setInt(_kTotal, withPhotos.length);

      final photoDir = await _getPhotoDirectory();
      final tempDir = await _getTempPhotoDirectory();

      final pending = withPhotos
          .where((s) => !completedRolls.contains(s.roll))
          .toList();

      report('Checking ${pending.length} photos at ${_headConcurrency}x...');

      // ── Worker ─────────────────────────────────────────────────────────
      int taskIndex = 0;
      final completedList = completedRolls.toList();

      Future<void> worker() async {
        while (taskIndex < pending.length) {
          final student = pending[taskIndex++];
          final liveFile = File('${photoDir.path}/${student.roll}.jpg');
          final tempFile = File('${tempDir.path}/${student.roll}.jpg');

          bool didFail = false;

          try {
            final needsDownload = !await liveFile.exists() ||
                await _remoteImageChanged(student.photoUrl, liveFile);

            checked++;

            if (needsDownload) {
              final ok = await _downloadWithRetry(
                  student.photoUrl, tempFile, _maxRetries);

              if (ok) {
                if (await liveFile.exists()) await liveFile.delete();
                await tempFile.rename(liveFile.path);
                downloaded++;
              } else {
                if (await tempFile.exists()) await tempFile.delete();
                didFail = true;
                failed++;
              }
            } else {
              skipped++;
            }
          } catch (_) {
            if (await tempFile.exists()) await tempFile.delete();
            didFail = true;
            failed++;
          }

          if (!didFail) completedList.add(student.roll);

          // Persist after every photo so resume is always accurate
          await prefs.setStringList(_kCompletedRolls, completedList);
          await prefs.setInt(_kChecked, checked);
          await prefs.setInt(_kDownloaded, downloaded);
          await prefs.setInt(_kFailed, failed);

          final total = withPhotos.length;
          final done = completedList.length;
          report('$done/$total  ↓$downloaded  ✓$skipped  ✗$failed');
        }
      }

      final workerCount = _concurrency.clamp(1, pending.isEmpty ? 1 : pending.length);
      await Future.wait(List.generate(workerCount, (_) => worker()));

      // Cleanup temp dir
      if (await tempDir.exists()) {
        await for (final f in tempDir.list()) {
          if (f is File) await f.delete().catchError((_) => f);
        }
      }

      final summary = 'Success: checked $checked  '
          'downloaded $downloaded  skipped $skipped  failed $failed';
      await _saveStatus('photo_sync_status', summary);
      await _clearPhotoSyncState(prefs);

      report('Done — $downloaded downloaded, $skipped unchanged, $failed failed.');

      return PhotoSyncStats(
        total: withPhotos.length,
        checked: checked,
        downloaded: downloaded,
        skipped: skipped,
        failed: failed,
      );
    } catch (e) {
      await _saveStatus('photo_sync_status', 'Failed: $e');
      rethrow;
    }
  }

  // ===========================================================================
  // DOWNLOAD WITH RETRY
  // ===========================================================================

  static Future<bool> _downloadWithRetry(
      String url, File dest, int maxRetries) async {
    if (!await dest.parent.exists()) {
      await dest.parent.create(recursive: true);
    }
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        await _dio.download(url, dest.path);
        return true;
      } catch (_) {
        if (attempt == maxRetries) return false;
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    return false;
  }

  // ===========================================================================
  // METADATA CHANGE DETECTION  (ETag → Last-Modified → Content-Length)
  // ===========================================================================

  static Future<bool> _remoteImageChanged(String url, File local) async {
    try {
      final response = await _dio.head(url);
      final headers = response.headers;

      final etag = headers.value('etag');
      if (etag != null && etag.isNotEmpty) {
        final sidecar = File('${local.path}.etag');
        if (await sidecar.exists()) {
          if (await sidecar.readAsString() == etag) return false;
        }
        return true;
      }

      final lastMod = headers.value('last-modified');
      if (lastMod != null && lastMod.isNotEmpty) {
        final sidecar = File('${local.path}.lm');
        if (await sidecar.exists()) {
          if (await sidecar.readAsString() == lastMod) return false;
        }
        return true;
      }

      final remoteLen =
          int.tryParse(headers.value('content-length') ?? '') ?? -1;
      if (remoteLen > 0) return remoteLen != await local.length();

      return false;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // DIRECTORIES
  // ===========================================================================

  static Future<Directory> _getPhotoDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _getTempPhotoDirectory() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/photos_temp');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ===========================================================================
  // RESUME STATE
  // ===========================================================================

  static Future<void> _clearPhotoSyncState(SharedPreferences prefs) async {
    await prefs.remove(_kInProgress);
    await prefs.remove(_kCompletedRolls);
    await prefs.remove(_kTotal);
    await prefs.remove(_kChecked);
    await prefs.remove(_kDownloaded);
    await prefs.remove(_kFailed);
  }

  static Future<bool> hasPendingPhotoSync() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kInProgress) ?? false;
  }

  static Future<int> pendingPhotoSyncProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_kCompletedRolls) ?? []).length;
  }

  static Future<int> pendingPhotoSyncTotal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_kTotal) ?? 0;
  }

  // ===========================================================================
  // URL BUILDER
  // ===========================================================================

  static String _buildCsvUrl(String input) {
    if (input.contains('export?format=csv') ||
        input.contains('pub?output=csv')) {
      return input;
    }
    final idMatch = RegExp(
      r'docs\.google\.com/spreadsheets/d/([a-zA-Z0-9\-_]+)',
    ).firstMatch(input);
    if (idMatch != null) {
      final id = idMatch.group(1)!;
      final gidMatch = RegExp(r'[?&]gid=(\d+)').firstMatch(input);
      final gid = gidMatch != null ? '&gid=${gidMatch.group(1)}' : '';
      return 'https://docs.google.com/spreadsheets/d/$id/export?format=csv$gid';
    }
    return input;
  }

  // ===========================================================================
  // HEADER VALIDATION
  // ===========================================================================

  static void _validateHeaders(List<dynamic> headerRow) {
    final headers =
        headerRow.map((e) => e.toString().trim().toLowerCase()).toList();
    for (int i = 0; i < _headerAliases.length; i++) {
      final accepted = _headerAliases[i];
      final actual = i < headers.length ? headers[i] : '(missing)';
      if (!accepted.contains(actual)) {
        throw Exception(
          'CSV header mismatch at column ${i + 1}. '
          'Accepted: ${accepted.join(' / ')}. '
          'Found: "$actual". '
          'Your headers: ${headers.join(', ')}',
        );
      }
    }
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  static Future<void> _saveStatus(String key, String message) async {
    final prefs = await SharedPreferences.getInstance();
    final time = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    await prefs.setString(key, '$message ($time)');
  }
}
