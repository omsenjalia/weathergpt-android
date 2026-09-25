import 'package:flutter/material.dart';

import '../errors/app_errors.dart';
import '../theme/app_colors.dart';

class ApiErrorView extends StatelessWidget {
  const ApiErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  String get _message {
    if (error is AppApiError) return (error as AppApiError).message;
    return error.toString();
  }

  @override
  Widget build(BuildContext context) {
    final network = error is NetworkError;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                network ? Icons.wifi_off_rounded : Icons.cloud_off_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 20),
              Text(
                network ? 'Connection problem' : 'Something went wrong',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 28),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Try again'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ctaWhite,
                    foregroundColor: AppColors.ctaTextDark,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
