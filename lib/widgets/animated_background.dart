import 'dart:math';

import 'package:flutter/material.dart';

import '../config/theme.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key, this.particleCount = 70});

  final int particleCount;

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _Particle {
  double x;
  double y;
  double vx;
  double vy;
  final double size;

  _Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
  });
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  final List<_Particle> _particles = [];
  Offset? _pointer;
  final Random _random = Random();
  late final AnimationController _controller;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _initParticles(Size size) {
    _particles.clear();
    for (var i = 0; i < widget.particleCount; i++) {
      _particles.add(_Particle(
        x: _random.nextDouble() * size.width,
        y: _random.nextDouble() * size.height,
        vx: (_random.nextDouble() - 0.5) * 0.5,
        vy: (_random.nextDouble() - 0.5) * 0.5,
        size: _random.nextDouble() * 2 + 1,
      ));
    }
    _lastSize = size;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    if (_particles.isEmpty || _lastSize != size) {
      _initParticles(size);
    }

    return SizedBox.expand(
      child: Listener(
        onPointerDown: (event) => _pointer = event.localPosition,
        onPointerMove: (event) => _pointer = event.localPosition,
        onPointerUp: (_) => _pointer = null,
        onPointerCancel: (_) => _pointer = null,
        child: CustomPaint(
          painter: _BackgroundPainter(this),
          isComplex: true,
        ),
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  _BackgroundPainter(this.state) : super(repaint: state._controller);

  final _AnimatedBackgroundState state;

  static const double _maxDistance = 150;
  static const double _pointerRadius = 100;
  static const Color _color = ZentraColors.primary;

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final particles = state._particles;
    final pointer = state._pointer;

    for (final particle in particles) {
      if (pointer != null) {
        final dx = particle.x - pointer.dx;
        final dy = particle.y - pointer.dy;
        final dist = sqrt(dx * dx + dy * dy);
        if (dist < _pointerRadius && dist > 0) {
          final force = ((_pointerRadius - dist) / _pointerRadius) * 0.03;
          final angle = atan2(dy, dx);
          particle.vx += cos(angle) * force;
          particle.vy += sin(angle) * force;
        }
      }

      final speed = sqrt(particle.vx * particle.vx + particle.vy * particle.vy);
      if (speed > 3) {
        final factor = 3 / speed;
        particle.vx *= factor;
        particle.vy *= factor;
      }

      particle.x += particle.vx;
      particle.y += particle.vy;

      if (particle.x < 0 || particle.x > size.width) particle.vx *= -1;
      if (particle.y < 0 || particle.y > size.height) particle.vy *= -1;
      particle.x = particle.x.clamp(0, size.width);
      particle.y = particle.y.clamp(0, size.height);
    }

    final linePaint = Paint()..strokeWidth = 1;
    for (var i = 0; i < particles.length; i++) {
      for (var j = i + 1; j < particles.length; j++) {
        final dx = particles[i].x - particles[j].x;
        final dy = particles[i].y - particles[j].y;
        final distance = sqrt(dx * dx + dy * dy);
        if (distance < _maxDistance) {
          final opacity = ((_maxDistance - distance) / _maxDistance) * 0.3;
          linePaint.color = _color.withOpacity(opacity);
          canvas.drawLine(
            Offset(particles[i].x, particles[i].y),
            Offset(particles[j].x, particles[j].y),
            linePaint,
          );
        }
      }
    }

    final dotPaint = Paint()..color = _color.withOpacity(0.8);
    for (final particle in particles) {
      canvas.drawCircle(Offset(particle.x, particle.y), particle.size, dotPaint);
    }
  }

}
