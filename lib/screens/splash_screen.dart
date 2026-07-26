import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Shown while the persisted session is resolved (AuthStatus.unknown).
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'vibe',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 40,
                fontWeight: FontWeight.w700,
                color: AppColors.onPrimary,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                  color: AppColors.onPrimary, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
