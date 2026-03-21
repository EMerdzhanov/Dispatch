import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

class DispatchApp extends StatelessWidget {
  const DispatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dispatch',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Scaffold(
        body: Center(child: Text('Dispatch')),
      ),
    );
  }
}
