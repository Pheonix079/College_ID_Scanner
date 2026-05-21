import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class CsvLinkScreen extends StatefulWidget {
  const CsvLinkScreen({super.key});

  @override
  State<CsvLinkScreen> createState() => _CsvLinkScreenState();
}

class _CsvLinkScreenState extends State<CsvLinkScreen> {
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urlController.text = prefs.getString('data_url') ?? '';
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('data_url', _urlController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link saved successfully')),
    );
  }

  // ── Sync helpers (fire-and-forget — runs in background) ─────────────────

  void _startDataSync() {
    SyncService.syncStudentData();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Data sync started in background'),
      duration: Duration(seconds: 2),
    ));
  }

  void _startPhotoSync() {
    SyncService.syncPhotos();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Photo sync started in background'),
      duration: Duration(seconds: 2),
    ));
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: AppBar(title: const Text('Admin Panel')),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          // ── URL editor ─────────────────────────────────────────────────────
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Google Sheet URL',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Paste your published Google Sheet or CSV link below.',
                  style: TextStyle(
                    color: AppTheme.textPrimary.withOpacity(0.60),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _urlController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'https://docs.google.com/spreadsheets/...',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: Icon(Icons.link_rounded),
                    ),
                    prefixIconConstraints: BoxConstraints(minWidth: 48),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Link'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Sync actions ───────────────────────────────────────────────────
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.sync_rounded,
                        color: AppTheme.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sync Controls',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.storage_rounded, size: 18),
                    label: const Text('Sync Data'),
                    onPressed: _startDataSync,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    label: const Text('Sync Photos'),
                    onPressed: _startPhotoSync,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── CSV format guide ───────────────────────────────────────────────
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.table_chart_outlined,
                        color: AppTheme.accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Required CSV Format',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _CsvFormatTable(),
                const SizedBox(height: 14),
                const Text(
                  'Example row',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.primary.withOpacity(0.12),
                    ),
                  ),
                  child: const Text(
                    '26409, Arjun Sharma, 3, CSE, 1, 21, https://drive.google.com/.../photo.jpg',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11.5,
                      height: 1.5,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const _SetupStep(
                  number: '1',
                  text: 'Open Google Sheets → File → Share → Publish to web',
                ),
                const SizedBox(height: 8),
                const _SetupStep(
                  number: '2',
                  text:
                      'Choose "Comma-separated values (.csv)" and copy the link',
                ),
                const SizedBox(height: 8),
                const _SetupStep(
                  number: '3',
                  text:
                      'Paste the link above and tap Save, then run Sync Data',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CsvFormatTable extends StatelessWidget {
  const _CsvFormatTable();

  @override
  Widget build(BuildContext context) {
    const columns = [
      ('roll', 'Roll No.', 'Unique student ID (used for QR scan)'),
      ('name', 'Name', 'Student full name'),
      ('year', 'Year', 'Academic year e.g. 3'),
      ('branch', 'Branch', 'e.g. CSE, ECE, CSIT'),
      ('bus_paid', 'Bus Paid', '"1" = paid, "0" = not paid'),
      ('bus_route_no', 'Route No.', 'Bus route number or leave blank'),
      ('photo_url', 'Photo URL', 'Direct image link (optional)'),
    ];

    return Column(
      children: columns.map((col) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 94,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  col.$1,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      col.$2,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      col.$3,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textPrimary.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SetupStep extends StatelessWidget {
  final String number;
  final String text;

  const _SetupStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary.withOpacity(0.75),
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
