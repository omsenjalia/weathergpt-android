import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OutlinedButtonPill extends StatelessWidget {
  const OutlinedButtonPill({super.key, required this.label, this.onPressed});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: const StadiumBorder(),
          ),
          child: Text(label),
        ),
      );
}
