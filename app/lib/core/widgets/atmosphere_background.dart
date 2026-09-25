import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../features/home/theme/atmosphere_theme.dart';

/// The immersive sky canvas behind non-home screens (chat, voice, settings,
/// persona hubs, onboarding).
///
/// It renders the same live sky Home shows — time-of-day gradient, sun/moon
/// disc at its real altitude, warm horizon band, drifting weather glow — and
/// then blurs the whole composition heavily, so every page visibly follows
/// time and weather *quietly*, keeping full contrast for the content above.
class AtmosphereBackground extends StatefulWidget {
  const AtmosphereBackground({
    super.key,
    required this.palette,
    this.scrim = true,
    this.animate = true,
    this.secondaryGlowOverride,
    this.glowOverride,
  });

  /// The live sky. Watch [atmospherePaletteProvider] upstream so palette
  /// changes (time crossing, weather turning) tween in automatically.
  final AtmospherePalette palette;

  /// Darkens the lower half so lists and cards stay legible.
  final bool scrim;

  final bool animate;

  /// Lets a screen tint the secondary glow (e.g. the voice result card tints
  /// it with its answer accent).
  final Color? secondaryGlowOverride;

  /// Persona hubs tint the main glow with their brand color.
  final Color? glowOverride;

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    if (widget.animate) _drift.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AtmosphereBackground old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_drift.isAnimating) {
      _drift.repeat(reverse: true);
    } else if (!widget.animate && _drift.isAnimating) {
      _drift.stop();
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final p = widget.palette;
    final secondary = widget.secondaryGlowOverride ?? p.accent;

    final sky = Stack(
      fit: StackFit.expand,
      children: [
        // Base vertical gradient, tweened so palette changes glide.
        TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: p.top),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOut,
          builder: (_, top, __) => TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: p.mid),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, mid, ___) => TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: p.bottom),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              builder: (_, bottom, ____) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      top ?? p.top,
                      mid ?? p.mid,
                      bottom ?? p.bottom,
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
        // Sun / moon disc at its real altitude — reads unmistakably as "the
        // sky moved" once blurred into a soft orb of light.
        if (p.showSun)
          _celestialBodies(
            y: p.sunY,
            color: const Color(0xFFFFE9A8),
            halo: const Color(0xFFFBBF24),
            size: size,
            t: _driftValue,
          ),
        if (p.showMoon)
          _celestialBodies(
            y: p.moonY,
            color: const Color(0xFFE2E8F0),
            halo: const Color(0xFF94A3B8),
            size: size,
            t: _driftValue + 0.5,
          ),
        // Warm band at the horizon for sunrise/sunset periods.
        if (p.horizonWarmth > 0)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: size.height * 0.42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFFB923C).withValues(alpha: 0),
                    const Color(0xFFF97316)
                        .withValues(alpha: 0.55 * p.horizonWarmth),
                  ],
                ),
              ),
            ),
          ),
        // Two slow-drifting weather glows (accent + secondary).
        AnimatedBuilder(
          animation: _drift,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_drift.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  left: -size.width * 0.35 + t * 30,
                  top: -size.height * 0.12 - t * 20,
                  child: _softCircle(size * 0.9, widget.glowOverride ?? p.glow, 0.20),
                ),
                Positioned(
                  right: -size.width * 0.30 - t * 26,
                  bottom: -size.height * 0.18 + t * 16,
                  child: _softCircle(size * 0.8, secondary, 0.14),
                ),
              ],
            );
          },
        ),
      ],
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // The "quiet" mandate: heavy gaussian blur over the whole sky so
          // it reads as a soft out-of-focus atmosphere, never competing
          // with chat/list content.
          IgnorePointer(
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 46, sigmaY: 46),
              child: sky,
            ),
          ),
          if (widget.scrim)
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.16),
                    Colors.black.withValues(alpha: 0.26),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
        ],
      ),
    );
  }

  double get _driftValue => Curves.easeInOut.transform(_drift.value);

  Widget _celestialBodies({
    required double y,
    required Color color,
    required Color halo,
    required Size size,
    required double t,
  }) {
    return Positioned(
      left: size.width * (0.60 + 0.06 * (t - 0.5)),
      top: size.height * y - 60,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.95),
              halo.withValues(alpha: 0.55),
              halo.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.35, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _softCircle(Size s, Color color, double alpha) => IgnorePointer(
        child: Container(
          width: s.width,
          height: s.height,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
            ),
          ),
        ),
      );
}
