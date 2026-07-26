import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/api_exception.dart';

/// Show a themed snackbar. Errors use the error color; successes the primary.
void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
}

/// Runs an async API action and surfaces the outcome as a snackbar:
/// - [ApiException] → its (already user-friendly) message as an error toast
/// - any other error → a generic error toast
/// - success → optional [successMessage]
/// Returns the action's result, or null on failure.
Future<T?> runWithFeedback<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? successMessage,
}) async {
  try {
    final result = await action();
    if (context.mounted && successMessage != null) {
      showSnack(context, successMessage);
    }
    return result;
  } on ApiException catch (e) {
    if (context.mounted) showSnack(context, e.message, isError: true);
    return null;
  } catch (_) {
    if (context.mounted) {
      showSnack(context, 'Something went wrong. Please try again.',
          isError: true);
    }
    return null;
  }
}
