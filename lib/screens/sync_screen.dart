import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/db_helper.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  // ── Persisted status strings ───────────────────────────────────────────────
  bool _loading = true;
  String _dataSyncStatus = 'Never';
  String _photoSyncStatus = 'Never';
  int _studentCount = 0;

  // ── Resume banner ──────────────────────────────────────────────────────────
  bool _hasResumable = false;
  int _resumeCompleted = 0;
  int _resumeTotal = 0;

  // ── Live background state ──────────────────────────────────────────────────
  late SyncState _syncState;
  StreamSubscription<SyncState>? _sub;

  // ── Last completed photo stats ─────────────────────────────────────────────
  PhotoSyncStats? _lastStats;

  @override
  void initState() {
    super.initState();
    _syncState = SyncService.currentState;
    _sub = SyncService.stateStream.listen((s) {
      if (!mounted) return;
      setState(() => _syncState = s);
      // When a sync just finished, refresh persisted status from prefs
      if (!s.dataSyncRunning && !s.photoSyncRunning) {
        _refreshStatus();
      }
      if (s.lastPhotoStats != null) {
        setState(() => _lastStats = s.lastPhotoStats);
      }
    });
    _load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // ── Load persisted data ────────────────────────────────────────────────────

  Future<void> _load() async {
    await _refreshStatus();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _refreshStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final dataSyncStatus = prefs.getString('data_sync_status') ?? 'Never';
    final photoSyncStatus = prefs.getString('photo_sync_status') ?? 'Never';
    final studentCount = await DBHelper.getStudentCount();
    final hasResumable = await SyncService.hasPendingPhotoSync();
    final resumeCompleted = await SyncService.pendingPhotoSyncProgress();
    final resumeTotal = await SyncService.pendingPhotoSyncTotal();

    if (!mounted) return;
    setState(() {
      _dataSyncStatus = dataSyncStatus;
      _photoSyncStatus = photoSyncStatus;
      _studentCount = studentCount;
      _hasResumable = hasResumable;
      _resumeCompleted = resumeCompleted;
      _resumeTotal = resumeTotal;
    });
  }

  // ── Trigger syncs (fire-and-forget — dialog is NOT blocking) ──────────────

  void _startDataSync() {
    SyncService.syncStudentData();
    _showBriefToast('Data sync started in background');
  }

  void _startPhotoSync() {
    SyncService.syncPhotos();
    _showBriefToast(_hasResumable
        ? 'Resuming photo sync in background...'
        : 'Photo sync started in background');
  }

  void _showBriefToast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  Widget _statusCard(String title, String value, {IconData? icon}) {
    return Card(
      child: ListTile(
        leading: icon != null ? Icon(icon, color: AppTheme.primary) : null,
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(value),
      ),
    );
  }

  Widget _statPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: color.withOpacity(0.80),
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _noteRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppTheme.primary.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textPrimary.withOpacity(0.70),
                    height: 1.4)),
          ),
        ],
      ),
    );
  }

  // ── Background activity bar ────────────────────────────────────────────────

  Widget _buildActivityBar() {
    final dataRunning = _syncState.dataSyncRunning;
    final photoRunning = _syncState.photoSyncRunning;

    if (!dataRunning && !photoRunning) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          if (dataRunning)
            _activityRow(
              icon: Icons.storage_rounded,
              label: 'Data Sync',
              message: _syncState.dataMessage,
            ),
          if (dataRunning && photoRunning) const Divider(height: 1),
          if (photoRunning)
            _activityRow(
              icon: Icons.photo_library_rounded,
              label: 'Photo Sync',
              message: _syncState.photoMessage,
            ),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(14)),
            child: const LinearProgressIndicator(minHeight: 3),
          ),
        ],
      ),
    );
  }

  Widget _activityRow(
      {required IconData icon,
      required String label,
      required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.primary)),
                if (message.isNotEmpty)
                  Text(message,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary.withOpacity(0.65))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppShell(child: Center(child: CircularProgressIndicator()));
    }

    final dataRunning = _syncState.dataSyncRunning;
    final photoRunning = _syncState.photoSyncRunning;

    return AppShell(
      appBar: AppBar(title: const Text('Sync Data')),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Live activity bar ────────────────────────────────────────────
          _buildActivityBar(),

          // ── Resume banner ────────────────────────────────────────────────
          if (_hasResumable && !photoRunning) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.pause_circle_outline_rounded,
                      color: Colors.orange.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Photo sync was interrupted.\n'
                      '$_resumeCompleted / $_resumeTotal done. '
                      'Tap "Resume" to continue.',
                      style: TextStyle(
                          color: Colors.orange.shade800,
                          fontSize: 13,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Action buttons ───────────────────────────────────────────────
          ElevatedButton.icon(
            icon: dataRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.storage_rounded),
            label: Text(dataRunning ? 'Syncing data…' : 'Sync Data'),
            onPressed: dataRunning ? null : _startDataSync,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: photoRunning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(_hasResumable
                    ? Icons.play_arrow_rounded
                    : Icons.photo_library_rounded),
            label: Text(photoRunning
                ? 'Syncing photos…'
                : _hasResumable
                    ? 'Resume Photo Sync'
                    : 'Sync Photos'),
            onPressed: photoRunning ? null : _startPhotoSync,
          ),

          const SizedBox(height: 24),

          // ── Last photo sync stats ────────────────────────────────────────
          if (_lastStats != null) ...[
            const Text('LAST PHOTO SYNC',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppTheme.secondary)),
            const SizedBox(height: 8),
            Row(children: [
              _statPill('Checked', '${_lastStats!.checked}', AppTheme.primary),
              _statPill('Downloaded', '${_lastStats!.downloaded}',
                  Colors.green.shade700),
              _statPill('Skipped', '${_lastStats!.skipped}', Colors.blueGrey),
              _statPill('Failed', '${_lastStats!.failed}', Colors.red.shade700),
            ]),
            const SizedBox(height: 20),
          ],

          // ── Status cards ─────────────────────────────────────────────────
          _statusCard('Students in database', _studentCount.toString(),
              icon: Icons.people_rounded),
          const SizedBox(height: 10),
          _statusCard('Data Sync Status', _dataSyncStatus,
              icon: Icons.storage_rounded),
          const SizedBox(height: 10),
          _statusCard('Photo Sync Status', _photoSyncStatus,
              icon: Icons.photo_library_rounded),

          const SizedBox(height: 24),

          // ── Info panel ───────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppTheme.primary.withOpacity(0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How sync works',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primary,
                        fontSize: 13)),
                const SizedBox(height: 8),
                _noteRow(Icons.bolt_rounded,
                    'Syncs run in the background — you can leave this screen freely.'),
                _noteRow(Icons.lock_rounded,
                    'Data sync: existing records stay live until new CSV is fully parsed.'),
                _noteRow(Icons.replay_rounded,
                    'Photo sync: resumes where it left off if interrupted.'),
                _noteRow(Icons.compare_arrows_rounded,
                    'Photos skipped if ETag / size unchanged (100 checked simultaneously).'),
                _noteRow(Icons.downloading_rounded,
                    'Up to 100 photos download simultaneously with auto-retry.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
