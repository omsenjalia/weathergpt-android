import 'package:flutter/material.dart';

import '../theme/atmosphere_theme.dart';

/// The circular mic button that launches voice input.
///
/// A breathing halo behind a glossy orb — static layout, one repeating
/// controller, cheap enough to run under the whole home screen.
class VoiceOrb extends StatefulWidget {
  const VoiceOrb({super.key, required this.palette, required this.onTap});
  final AtmospherePalette palette;
  final VoidCallback onTap;

  @override
  State<VoiceOrb> createState() => _VoiceOrbState();
}

class _VoiceOrbState extends State<VoiceOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _breathe,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_breathe.value);
          return Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [p.orbStart, p.orbEnd],
              ),
              boxShadow: [
                BoxShadow(
                  color: p.accent.withValues(alpha: 0.35 + 0.2 * t),
                  blurRadius: 26 + 10 * t,
                  spreadRadius: 2 + 3 * t,
                ),
              ],
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.black87, size: 32),
          );
        },
      ),
    );
  }
}
