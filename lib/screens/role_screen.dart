import 'package:flutter/material.dart';
import 'sync_screen.dart';
import 'scanner_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import '../widgets/admin_login_dialog.dart';

class RoleScreen extends StatefulWidget {
  const RoleScreen({super.key});

  @override
  State<RoleScreen> createState() => _RoleScreenState();
}

class _RoleScreenState extends State<RoleScreen> {
  int _tapCount = 0;
  DateTime? _lastTap;

  void _onLogoTap() {
    final now = DateTime.now();
    if (_lastTap != null &&
        now.difference(_lastTap!) > const Duration(seconds: 3)) {
      _tapCount = 0;
    }
    _lastTap = now;
    _tapCount++;
    if (_tapCount >= 7) {
      _tapCount = 0;
      showAdminLogin(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Column(
        children: [
          // ── Logo ──────────────────────────────────────────────
          GestureDetector(
            onTap: _onLogoTap,
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  'assets/dronacharya_logo.jpg', // Path fixed to point to root assets folder
                  fit: BoxFit.contain,
                  height: 90,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      'DRONACHARYA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.primary,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'STUDENT VERIFICATION',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary.withOpacity(0.55),
                letterSpacing: 3.5,
              ),
            ),
          ),

          const SizedBox(height: 28),

          // ── Big action buttons ────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
              child: Column(
                children: [
                  // SCAN
                  Expanded(
                    child: _BigActionButton(
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'Scan Student ID',
                      subtitle: 'Open camera and verify\na student in seconds',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ScannerScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // SYNC
                  Expanded(
                    child: _BigActionButton(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Sync to Update Data',
                      subtitle: 'Refresh student records\nfrom the cloud',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SyncScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary.withOpacity(0.55),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text(
                title.split(' ').first == 'Scan'
                    ? 'Start Scanner'
                    : 'Start Sync',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
