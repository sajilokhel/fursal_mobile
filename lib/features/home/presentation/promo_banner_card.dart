import 'dart:async';
import 'package:flutter/material.dart';

class PromoBannerCard extends StatefulWidget {
  final VoidCallback? onBookNow;

  const PromoBannerCard({super.key, this.onBookNow});

  @override
  State<PromoBannerCard> createState() => _PromoBannerCardState();
}

class _PromoBannerCardState extends State<PromoBannerCard>
    with TickerProviderStateMixin {
  static const _sports = [
    ('⚽', 'Futsal'),
    ('🏸', 'Badminton'),
    ('🏏', 'Cricket'),
    ('🏀', 'Basketball'),
    ('🏐', 'Volleyball'),
    ('🎾', 'Tennis'),
  ];

  int _index = 0;
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final Animation<double> _floatAnim;
  late final Animation<double> _fadeAnim;
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: 10).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..value = 1.0;

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _timer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _fadeController.reverse();
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _sports.length);
      _fadeController.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (emoji, sport) = _sports[_index];

    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).primaryColor.withOpacity(0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── Arc decoration top-right ──────────────────────
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.07),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: -50,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
            ),
            // ── Dotted pattern strip ──────────────────────────
            Positioned(
              left: 0,
              bottom: 0,
              right: 0,
              child: _DotStrip(),
            ),
            // ── Big floating emoji (right side) ──────────────
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -_floatAnim.value),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // ── Content ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 100, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Tag pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Text(
                        'Play $sport Today!',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Headline
                  const Text(
                    'Get on\nthe Field! 🏟️',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // CTA button
                  GestureDetector(
                    onTap: widget.onBookNow,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Find a Venue',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: Theme.of(context).primaryColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of faint dots for texture at the bottom of the banner.
class _DotStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: CustomPaint(painter: _DotPainter()),
    );
  }
}

class _DotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;
    const spacing = 14.0;
    const r = 2.5;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = r; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), r, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
