import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/atmosphere_theme.dart';

class AtmosphereBackground extends StatefulWidget {
  const AtmosphereBackground({
    super.key,
    required this.palette,
    required this.sky,
    required this.period,
    this.particlesOnly = false,
  });

  final AtmospherePalette palette;
  final SkyCondition sky;
  final SkyPeriod period;
  /// When true, skip base gradient (for use as overlay on video).
  final bool particlesOnly;

  @override
  State<AtmosphereBackground> createState() => _AtmosphereBackgroundState();
}

class _AtmosphereBackgroundState extends State<AtmosphereBackground>
    with TickerProviderStateMixin {
  late final AnimationController _slow; // sun/moon drift
  late final AnimationController _pulse; // glow breathe
  late final AnimationController _rain; // precipitation
  late final AnimationController _flash; // lightning timing

  @override
  void initState() {
    super.initState();
    _slow = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat(reverse: true);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
    _rain = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat();
    _flash = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _slow.dispose();
    _pulse.dispose();
    _rain.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_slow, _pulse, _rain, _flash]),
      builder: (context, _) {
        return CustomPaint(
          painter: _SkyPainter(
            palette: widget.palette,
            sky: widget.sky,
            period: widget.period,
            drift: _slow.value,
            pulse: _pulse.value,
            rainT: _rain.value,
            flashT: _flash.value,
            particlesOnly: widget.particlesOnly,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.palette,
    required this.sky,
    required this.period,
    required this.drift,
    required this.pulse,
    required this.rainT,
    required this.flashT,
    this.particlesOnly = false,
  });

  final AtmospherePalette palette;
  final SkyCondition sky;
  final SkyPeriod period;
  final double drift;
  final double pulse;
  final double rainT;
  final double flashT;
  final bool particlesOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (particlesOnly) {
      _paintStars(canvas, size);
      _paintSun(canvas, size);
      _paintMoon(canvas, size);
      _paintClouds(canvas, size);
      _paintFog(canvas, size);
      _paintRain(canvas, size);
      _paintSnow(canvas, size);
      _paintWind(canvas, size);
      _paintThunder(canvas, size);
      return;
    }

    // --- Base gradient sky ---
    final colors = <Color>[palette.top, palette.mid, palette.bottom];
    final stops = palette.horizonWarmth > 0.3
        ? <double>[0.0, 0.38, 1.0]
        : <double>[0.0, 0.48, 1.0];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );

    // Horizon warm band (sunrise/sunset)
    if (palette.horizonWarmth > 0.05) {
      final bandH = size.height * (0.35 + palette.horizonWarmth * 0.15);
      final bandTop = size.height - bandH;
      canvas.drawRect(
        Rect.fromLTWH(0, bandTop, size.width, bandH),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Color.lerp(
                const Color(0xFFFFEDD5),
                const Color(0xFFEA580C),
                palette.horizonWarmth,
              )!
                  .withValues(alpha: 0.15 + palette.horizonWarmth * 0.25),
              Color.lerp(
                const Color(0xFFFBBF24),
                const Color(0xFFC2410C),
                palette.horizonWarmth,
              )!
                  .withValues(alpha: 0.12 + palette.horizonWarmth * 0.2),
            ],
          ).createShader(Rect.fromLTWH(0, bandTop, size.width, bandH)),
      );
    }

    // Ambient glow
    final glowC = Offset(
      size.width * (0.55 + (drift - 0.5) * 0.1),
      size.height * 0.2,
    );
    canvas.drawCircle(
      glowC,
      size.width * (0.5 + pulse * 0.06),
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.glow.withValues(alpha: 0.32),
            palette.glow.withValues(alpha: 0.0),
          ],
        ).createShader(
          Rect.fromCircle(center: glowC, radius: size.width * 0.55),
        ),
    );

    _paintStars(canvas, size);
    _paintSun(canvas, size);
    _paintMoon(canvas, size);
    _paintClouds(canvas, size);
    _paintFog(canvas, size);
    _paintRain(canvas, size);
    _paintSnow(canvas, size);
    _paintWind(canvas, size);
    _paintThunder(canvas, size);
  }

  void _paintStars(Canvas canvas, Size size) {
    final night = period == SkyPeriod.night ||
        period == SkyPeriod.midnight ||
        period == SkyPeriod.evening ||
        period == SkyPeriod.dusk ||
        period == SkyPeriod.predawn;
    if (!night) return;
    if (sky == SkyCondition.overcast ||
        sky == SkyCondition.fog ||
        sky == SkyCondition.heavyRain) {
      return;
    }

    final count = period == SkyPeriod.midnight ? 70 : 45;
    final rnd = math.Random(42);
    for (var i = 0; i < count; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height * 0.5;
      final twinkle =
          0.25 + 0.75 * ((math.sin(rainT * math.pi * 2 + i * 0.7) + 1) / 2);
      final r = rnd.nextDouble() * 1.5 + 0.3;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()..color = Colors.white.withValues(alpha: twinkle * 0.85),
      );
    }
  }

  void _paintSun(Canvas canvas, Size size) {
    if (!palette.showSun) return;
    final sun = Offset(
      size.width * (0.74 + (drift - 0.5) * 0.05),
      size.height * palette.sunY.clamp(0.06, 0.92),
    );
    final core = 26.0 + pulse * 5;

    // God rays at sunrise/golden hour
    if (period == SkyPeriod.sunrise ||
        period == SkyPeriod.goldenHour ||
        period == SkyPeriod.sunset) {
      final rayPaint = Paint()
        ..shader = RadialGradient(
          colors: [
            palette.orbStart.withValues(alpha: 0.22),
            palette.orbEnd.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: core * 6));
      canvas.drawCircle(sun, core * 6, rayPaint);
    }

    // Outer corona
    canvas.drawCircle(
      sun,
      core * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            palette.orbStart.withValues(alpha: 0.5),
            palette.orbEnd.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: sun, radius: core * 2.6)),
    );
    // Core
    canvas.drawCircle(
      sun,
      core,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFFFF0), palette.orbStart, palette.orbEnd],
          stops: const [0.0, 0.45, 1.0],
        ).createShader(Rect.fromCircle(center: sun, radius: core)),
    );
  }

  void _paintMoon(Canvas canvas, Size size) {
    if (!palette.showMoon) return;
    final moon = Offset(
      size.width * (0.2 + (drift - 0.5) * 0.04),
      size.height * palette.moonY.clamp(0.08, 0.55),
    );
    final r = 17.0 + pulse * 2.2;

    canvas.drawCircle(
      moon,
      r * 2.0,
      Paint()..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.drawCircle(moon, r, Paint()..color = const Color(0xFFE8EEF7));
    // craters
    canvas.drawCircle(
      moon.translate(-r * 0.25, r * 0.1),
      r * 0.22,
      Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      moon.translate(r * 0.2, -r * 0.15),
      r * 0.14,
      Paint()..color = const Color(0xFFCBD5E1).withValues(alpha: 0.35),
    );
    // crescent shadow for predawn / thin moon feel
    if (period == SkyPeriod.predawn || period == SkyPeriod.dusk) {
      canvas.drawCircle(
        moon.translate(r * 0.4, -r * 0.05),
        r * 0.9,
        Paint()..color = palette.top,
      );
    }
  }

  void _paintClouds(Canvas canvas, Size size) {
    final cloudy = sky == SkyCondition.cloudy ||
        sky == SkyCondition.partlyCloudy ||
        sky == SkyCondition.overcast ||
        sky == SkyCondition.rain ||
        sky == SkyCondition.heavyRain ||
        sky == SkyCondition.drizzle ||
        sky == SkyCondition.thunder ||
        sky == SkyCondition.snow;
    if (!cloudy) return;

    final dense = sky == SkyCondition.overcast ||
        sky == SkyCondition.heavyRain ||
        sky == SkyCondition.thunder;
    final alpha = dense ? 0.2 : 0.12;
    final count = dense ? 7 : 4;
    final paint = Paint()..color = Colors.white.withValues(alpha: alpha);

    for (var i = 0; i < count; i++) {
      final speed = 0.04 + i * 0.012;
      final cx = size.width * ((0.18 * i + drift * speed) % 1.15) - size.width * 0.08;
      final cy = size.height * (0.08 + (i % 3) * 0.07);
      final w = 120.0 + i * 28;
      final h = 34.0 + i * 5.0;
      _cloudBlob(canvas, Offset(cx, cy), w, h, paint);
    }
  }

  void _cloudBlob(Canvas canvas, Offset c, double w, double h, Paint paint) {
    canvas.drawOval(
        Rect.fromCenter(center: c, width: w, height: h), paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(-w * 0.25, h * 0.1),
            width: w * 0.55,
            height: h * 0.85),
        paint);
    canvas.drawOval(
        Rect.fromCenter(
            center: c.translate(w * 0.28, h * 0.05),
            width: w * 0.5,
            height: h * 0.75),
        paint);
  }

  void _paintFog(Canvas canvas, Size size) {
    if (sky != SkyCondition.fog) return;
    for (var i = 0; i < 4; i++) {
      final y = size.height * (0.25 + i * 0.15);
      final shift = (drift - 0.5) * 40 * (i.isEven ? 1 : -1);
      canvas.drawRect(
        Rect.fromLTWH(shift - 20, y, size.width + 40, size.height * 0.12),
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.0),
              Colors.white.withValues(alpha: 0.14 - i * 0.02),
              Colors.white.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(0, y, size.width, size.height * 0.12),
          ),
      );
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    if (sky != SkyCondition.rain &&
        sky != SkyCondition.heavyRain &&
        sky != SkyCondition.drizzle &&
        sky != SkyCondition.thunder) {
      return;
    }
    final heavy = sky == SkyCondition.heavyRain || sky == SkyCondition.thunder;
    final drizzle = sky == SkyCondition.drizzle;
    final count = drizzle ? 40 : (heavy ? 110 : 75);
    final len = drizzle ? 8.0 : (heavy ? 18.0 : 13.0);
    final rnd = math.Random(11);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: drizzle ? 0.22 : 0.38)
      ..strokeWidth = drizzle ? 1.0 : 1.35
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < count; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final fall = (baseY + rainT * size.height * (heavy ? 1.4 : 1.0)) %
          (size.height + 20);
      final wind = rainT * (heavy ? 35.0 : 18.0);
      final x = (baseX + wind + i * 0.3) % size.width;
      canvas.drawLine(
        Offset(x, fall),
        Offset(x - (heavy ? 5 : 3), fall + len),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    if (sky != SkyCondition.snow) return;
    final rnd = math.Random(21);
    for (var i = 0; i < 55; i++) {
      final baseX = rnd.nextDouble() * size.width;
      final baseY = rnd.nextDouble() * size.height;
      final fall = (baseY + rainT * size.height * 0.45) % (size.height + 10);
      final sway = math.sin(rainT * math.pi * 2 + i) * 12;
      final x = (baseX + sway) % size.width;
      final r = rnd.nextDouble() * 2.2 + 1.0;
      canvas.drawCircle(
        Offset(x, fall),
        r,
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
  }

  void _paintWind(Canvas canvas, Size size) {
    if (sky != SkyCondition.windy) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final y = size.height * (0.15 + i * 0.06);
      final x0 = (rainT * size.width * 1.2 + i * 50) % (size.width + 80) - 40;
      canvas.drawLine(Offset(x0, y), Offset(x0 + 40 + i * 2, y - 2), paint);
    }
  }

  void _paintThunder(Canvas canvas, Size size) {
    if (sky != SkyCondition.thunder) return;

    // Occasional full-screen flash
    final wave = math.sin(flashT * math.pi * 2);
    final secondary = math.sin(flashT * math.pi * 2 * 3.1);
    if (wave > 0.94 || (wave > 0.88 && secondary > 0.9)) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.white.withValues(alpha: 0.2),
      );
    }

    // Lightning bolt (brief)
    if (wave > 0.91) {
      final path = Path();
      final startX = size.width * (0.3 + (drift * 0.4));
      path.moveTo(startX, size.height * 0.05);
      path.lineTo(startX - 18, size.height * 0.22);
      path.lineTo(startX + 8, size.height * 0.22);
      path.lineTo(startX - 12, size.height * 0.45);
      path.lineTo(startX + 22, size.height * 0.28);
      path.lineTo(startX + 4, size.height * 0.28);
      path.lineTo(startX + 28, size.height * 0.05);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFE0E7FF).withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) =>
      old.drift != drift ||
      old.pulse != pulse ||
      old.rainT != rainT ||
      old.flashT != flashT ||
      old.sky != sky ||
      old.period != period ||
      old.palette != palette;
}
