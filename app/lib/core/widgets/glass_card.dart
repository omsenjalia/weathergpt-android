import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Frosted-glass surface used across the app.
///
/// Two tiers:
/// - [blur] (default false): translucent dark fill + hairline border. Cheap
///   enough for grids and lists — this is the default card of the design
///   system.
/// - [blur] true: real `BackdropFilter` frosted glass for chrome that floats
///   above changing content (nav bar, chat composer). Use sparingly; blurred
///   layers are expensive on low-end devices.
///
/// The fill is intentionally a translucent DARK navy on every sky: white text
/// must stay readable on bright daylight gradients, so cards never turn into
/// white glass.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.blur = false,
    this.strong = false,
    this.borderColor,
    this.gradient,
    this.onTap,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final bool strong;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final fill = strong ? AppColors.glassFillStrong : AppColors.glassFill;
    final outline =
        borderColor ?? (strong ? AppColors.glassBorderStrong : AppColors.glassBorder);

    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: gradient,
        color: gradient == null ? fill : null,
        border: Border.all(color: outline),
      ),
      child: child,
    );

    Widget result = blur
        ? ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: AppColors.glassBlurRadius,
                sigmaY: AppColors.glassBlurRadius,
              ),
              child: body,
            ),
          )
        : body;

    if (onTap != null) {
      result = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: result,
        ),
      );
    }
    if (margin != null) {
      result = Padding(padding: margin!, child: result);
    }
    return result;
  }
}
