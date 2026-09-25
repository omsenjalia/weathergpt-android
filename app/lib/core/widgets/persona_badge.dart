import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PersonaBadge extends StatelessWidget {
  const PersonaBadge({super.key, required this.label, this.selected = false});
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: selected ? AppColors.farmerGreen : Colors.transparent,
              shape: BoxShape.circle,
              border: selected
                  ? null
                  : Border.all(color: AppColors.borderSubtle, width: 1.5),
            ),
            child: selected
                ? const Icon(Icons.check, size: 14, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
}
