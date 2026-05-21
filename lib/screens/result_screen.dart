import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/student.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class ResultScreen extends StatelessWidget {
  final Student student;
  final DateTime scannedAt;

  const ResultScreen({
    super.key,
    required this.student,
    required this.scannedAt,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPaid = student.busPaid;

    // Format: Friday, 16 May 2026  •  10:34:07 AM
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(scannedAt);
    final timeStr = DateFormat('hh:mm:ss a').format(scannedAt);

    return AppShell(
      appBar: AppBar(title: const Text('Student Details')),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          children: [
            PremiumPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Photo + basic info ────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: student.photoPath.isNotEmpty
                            ? Image.file(
                                File(student.photoPath),
                                height: 150,
                                width: 120,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.low,
                                errorBuilder: (_, __, ___) => _fallbackPhoto(),
                              )
                            : _fallbackPhoto(),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: SizedBox(
                          height: 150,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _infoRow('Roll No', student.roll),
                              const SizedBox(height: 8),
                              _infoRow('Year', student.year),
                              const SizedBox(height: 8),
                              _infoRow('Branch', student.branch),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Scan timestamp ────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.primary.withOpacity(0.14)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.access_time_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Scanned at',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.secondary,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeStr,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary.withOpacity(0.65),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Transport info ────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.72),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Transport Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Icon(
                              isPaid ? Icons.check_circle : Icons.cancel,
                              color: isPaid ? Colors.green : Colors.red,
                              size: 30,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isPaid ? 'FEES PAID' : 'FEES NOT PAID',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: isPaid
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_bus,
                                  size: 24, color: AppTheme.primary),
                              const SizedBox(width: 12),
                              Text(
                                student.busRouteNo.isEmpty
                                    ? 'Route Not Assigned'
                                    : 'Route ${student.busRouteNo}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan New ID'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Widget _fallbackPhoto() {
    return Container(
      height: 150,
      width: 120,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Colors.grey.shade200),
      child: const Icon(Icons.person, size: 60, color: Colors.grey),
    );
  }
}
