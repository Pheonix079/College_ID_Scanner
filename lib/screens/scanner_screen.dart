import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../database/db_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'manual_search_screen.dart';
import 'result_screen.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  bool _processing = false;
  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      autoStart: true,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
        _controller.stop();
        break;
      default:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null) return;

    _processing = true;
    await _controller.stop();

    final student = await DBHelper.getStudent(code.trim());
    if (!mounted) {
      _processing = false;
      return;
    }

    if (student != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResultScreen(student: student, scannedAt: DateTime.now())),
      );

      // Resume camera after returning from result screen
      if (mounted) {
        await _controller.start();
      }
      _processing = false;
    } else {
      // Show better error dialog instead of just a snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid QR or student not in database.'),
          backgroundColor: Colors.redAccent,
        ),
      );

      // NEW FIX: 2-Second Cooldown.
      // This stops the camera from immediately re-reading the bad QR code.
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        await _controller.start();
      }
      _processing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      useSafeArea: false,
      appBar: AppBar(
        title: const Text('Scan Student ID'),
        actions: [
          IconButton(
            tooltip: 'Manual Search',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManualSearchScreen()),
            ),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Camera feed
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error, child) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt_outlined,
                            size: 64, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(
                          'Camera unavailable:\n${error.errorDetails?.message ?? error.errorCode.name}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Scan frame overlay
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanOverlayPainter()),
            ),
          ),

          // Top hint card
          Positioned(
            left: 20,
            right: 20,
            top: MediaQuery.of(context).padding.top + 64,
            child: PremiumPanel(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.center_focus_strong_rounded,
                        color: AppTheme.secondary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Align the student\'s QR code inside the frame.',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom controls
          Positioned(
            left: 20,
            right: 20,
            bottom: 32,
            child: PremiumPanel(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _controller.toggleTorch(),
                      icon: const Icon(Icons.flashlight_on_outlined),
                      label: const Text('Torch'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ManualSearchScreen()),
                      ),
                      icon: const Icon(Icons.search_rounded),
                      label: const Text('Manual'),
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

class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dimPaint = Paint()..color = Colors.black.withOpacity(0.50);
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const boxSize = 240.0;
    const r = 16.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: boxSize, height: boxSize),
      const Radius.circular(r),
    );

    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), dimPaint);
    canvas.drawRRect(rect, clearPaint);
    canvas.restore();
    canvas.drawRRect(rect, borderPaint);
  }

  @override
  bool shouldRepaint(_) => false;
}
