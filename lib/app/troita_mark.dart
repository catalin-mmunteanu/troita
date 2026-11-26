import 'package:material_ui/material_ui.dart';

/// The troiță of the app icon (`ic_launcher_foreground.xml`): a roof over a
/// cross, drawn on a 108-unit grid like the adaptive icon, so the splash,
/// the onboarding and the launcher show the same shape.
///
/// [post], [arm], [roof] and [glow] run from 0 (absent) to 1 (in place);
/// [TroitaMark.still] has them all at 1.
class TroitaMark extends StatelessWidget {
  const TroitaMark({
    super.key,
    required this.size,
    this.color = TroitaMark.cream,
    this.post = 1,
    this.arm = 1,
    this.roof = 1,
    this.glow = 0,
  });

  const TroitaMark.still({super.key, required this.size, this.color = TroitaMark.cream})
      : post = 1,
        arm = 1,
        roof = 1,
        glow = 0;

  static const Color cream = Color(0xFFF7F3EC);

  /// `ic_launcher_background`.
  static const Color burgundy = Color(0xFF8C2F2A);

  final double size;
  final Color color;
  final double post;
  final double arm;
  final double roof;
  final double glow;

  @override
  Widget build(BuildContext context) {
    final double u = size / 108;
    Rect r(double x, double y, double w, double h) =>
        Rect.fromLTWH(x * u, y * u, w * u, h * u);
    final Rect postR = r(49, 45, 10, 47);
    final Rect armR = r(34, 55, 40, 10);
    final Rect roofR = r(24, 26, 60, 19);
    return Semantics(
      label: 'Troița',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            if (glow > 0)
              Positioned.fromRect(
                rect: r(4, 14, 100, 100),
                child: Opacity(
                  opacity: glow.clamp(0.0, 1.0),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          Color(0x8CD4AF37),
                          Color(0x2ED4AF37),
                          Color(0x00D4AF37),
                        ],
                        stops: <double>[0, 0.45, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fromRect(
              rect: roofR,
              child: Opacity(
                opacity: roof.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, -11 * u * (1 - roof)),
                  child: ClipPath(
                    clipper: _RoofClipper(),
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
            Positioned.fromRect(
              rect: postR,
              child: Transform.scale(
                scaleY: post.clamp(0.0, 1.0),
                alignment: Alignment.bottomCenter,
                child: ColoredBox(color: color),
              ),
            ),
            Positioned.fromRect(
              rect: armR,
              child: Transform.scale(
                scaleX: arm.clamp(0.0, 1.0),
                child: ColoredBox(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// M54,26 L24,40 v5 h60 v-5 z, in the roof's own box (60 × 19).
class _RoofClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width / 2, 0)
    ..lineTo(0, s.height * 14 / 19)
    ..lineTo(0, s.height)
    ..lineTo(s.width, s.height)
    ..lineTo(s.width, s.height * 14 / 19)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// "Troița se ridică": the first-run splash. The post grows, the arm opens,
/// the roof comes down, a candle-warm light shows once, the word appears.
/// About 2.4 s; [onDone] then. With "remove animations" on, the finished
/// picture at once.
class TroitaSplash extends StatefulWidget {
  const TroitaSplash({super.key, this.animate = true, this.onDone});

  /// Off for ordinary starts: the still mark while the data opens.
  final bool animate;
  final VoidCallback? onDone;

  @override
  State<TroitaSplash> createState() => _TroitaSplashState();
}

class _TroitaSplashState extends State<TroitaSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    if (!widget.animate || MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone?.call());
      return;
    }
    _c.forward().whenComplete(() => widget.onDone?.call());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _span(double t, double from, double to, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: TroitaMark.burgundy,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (BuildContext context, _) {
            final double t = _c.value;
            // The light rises to its peak and settles at a glimmer.
            final double glow = t < 0.62
                ? 0.75 * _span(t, 0.38, 0.62)
                : 0.75 - 0.35 * _span(t, 0.62, 0.85);
            final double word = _span(t, 0.55, 0.8);
            // The mark sits dead centre, where Android's launch screen put
            // it; the word hangs below without moving it.
            return Stack(
              alignment: Alignment.center,
              children: <Widget>[
                TroitaMark(
                  size: 216,
                  post: _span(t, 0.0, 0.2),
                  arm: _span(t, 0.16, 0.34),
                  roof: _span(t, 0.3, 0.5),
                  glow: widget.animate ? glow : 0,
                ),
                Transform.translate(
                  offset: Offset(0, 140 + 10 * (1 - word)),
                  child: Opacity(
                    opacity: word,
                    // The word keeps its size: it is a logo, not text to read.
                    child: const Text(
                      'Troița',
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: 'Literata',
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFFDFBF7),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
