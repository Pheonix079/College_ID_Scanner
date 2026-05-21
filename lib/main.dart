import 'package:flutter/material.dart';

import 'screens/role_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DronacharyaStudentVerificationApp());
}

class DronacharyaStudentVerificationApp extends StatelessWidget {
  const DronacharyaStudentVerificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dronacharya Student Verification',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const RoleScreen(),
    );
  }
}
