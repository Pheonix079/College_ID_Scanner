import 'package:flutter/material.dart';

import '../database/db_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'result_screen.dart';

class ManualSearchScreen extends StatefulWidget {
  const ManualSearchScreen({super.key});

  @override
  State<ManualSearchScreen> createState() => _ManualSearchScreenState();
}

class _ManualSearchScreenState extends State<ManualSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final roll = _controller.text.trim();
    if (roll.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a roll number to continue.')),
      );
      return;
    }

    setState(() => _searching = true);
    final student = await DBHelper.getStudent(roll);
    if (!mounted) return;
    setState(() => _searching = false);

    if (student == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No student found for that roll number.')),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(student: student, scannedAt: DateTime.now())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      appBar: AppBar(title: const Text('Manual Search')),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const SectionHeader(
            eyebrow: 'Search',
            title: 'Find a student instantly',
            subtitle:
                'Use the stored offline database to search any student by roll number when scanning is not convenient.',
          ),
          const SizedBox(height: 18),
          PremiumPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Roll Number Lookup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                Text(
                  'Search works on the latest synced records available on this device.',
                  style: TextStyle(
                    color: AppTheme.textPrimary.withOpacity(0.70),
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: const InputDecoration(
                    labelText: 'Enter roll number',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _searching ? null : _search,
                  icon: _searching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(_searching ? 'Searching...' : 'Search Student'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const PremiumPanel(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.tips_and_updates_outlined, color: AppTheme.accent),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: sync the database before searching if you expect newly added students to appear.',
                    style: TextStyle(height: 1.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
