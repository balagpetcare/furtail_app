import 'package:flutter/material.dart';

class LikePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFF1b74e4);
    final path = Path()
      ..moveTo(size.width * 0.6, size.height * 0.35)
      ..lineTo(size.width * 0.57, size.height * 0.16)
      ..cubicTo(
        size.width * 0.56,
        size.height * 0.11,
        size.width * 0.51,
        size.height * 0.09,
        size.width * 0.46,
        size.height * 0.12,
      )
      ..lineTo(size.width * 0.35, size.height * 0.22)
      ..cubicTo(
        size.width * 0.32,
        size.height * 0.24,
        size.width * 0.3,
        size.height * 0.27,
        size.width * 0.29,
        size.height * 0.3,
      )
      ..lineTo(size.width * 0.29, size.height * 0.7)
      ..lineTo(size.width * 0.68, size.height * 0.7)
      ..cubicTo(
        size.width * 0.73,
        size.height * 0.7,
        size.width * 0.77,
        size.height * 0.67,
        size.width * 0.78,
        size.height * 0.63,
      )
      ..lineTo(size.width * 0.85, size.height * 0.35)
      ..cubicTo(
        size.width * 0.87,
        size.height * 0.29,
        size.width * 0.82,
        size.height * 0.24,
        size.width * 0.77,
        size.height * 0.24,
      )
      ..lineTo(size.width * 0.6, size.height * 0.24)
      ..close();
    final thumbPath = Path()
      ..moveTo(size.width * 0.12, size.height * 0.33)
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.33,
        size.width * 0.04,
        size.height * 0.37,
        size.width * 0.04,
        size.height * 0.41,
      )
      ..lineTo(size.width * 0.04, size.height * 0.7)
      ..cubicTo(
        size.width * 0.04,
        size.height * 0.75,
        size.width * 0.08,
        size.height * 0.79,
        size.width * 0.12,
        size.height * 0.79,
      )
      ..lineTo(size.width * 0.21, size.height * 0.79)
      ..lineTo(size.width * 0.21, size.height * 0.33)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawPath(thumbPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFf33e58);
    final path = Path()
      ..moveTo(size.width * 0.5, size.height * 0.89)
      ..lineTo(size.width * 0.44, size.height * 0.83)
      ..cubicTo(
        size.width * 0.22,
        size.height * 0.64,
        size.width * 0.08,
        size.height * 0.51,
        size.width * 0.08,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.22,
        size.width * 0.18,
        size.height * 0.12,
        size.width * 0.31,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.38,
        size.height * 0.12,
        size.width * 0.45,
        size.height * 0.15,
        size.width * 0.5,
        size.height * 0.21,
      )
      ..cubicTo(
        size.width * 0.54,
        size.height * 0.15,
        size.width * 0.61,
        size.height * 0.12,
        size.width * 0.68,
        size.height * 0.12,
      )
      ..cubicTo(
        size.width * 0.81,
        size.height * 0.12,
        size.width * 0.91,
        size.height * 0.22,
        size.width * 0.91,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.91,
        size.height * 0.51,
        size.width * 0.77,
        size.height * 0.64,
        size.width * 0.56,
        size.height * 0.83,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FacePainter extends CustomPainter {
  final Color baseColor;
  final Function(Canvas, Size) drawFace;
  FacePainter(this.baseColor, this.drawFace);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2.4,
      Paint()..color = baseColor,
    );
    drawFace(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ReactionDef {
  final String type;
  final String label;
  final Widget icon;
  final Color color;

  const ReactionDef({
    required this.type,
    required this.label,
    required this.icon,
    required this.color,
  });
}

final List<ReactionDef> reactions = [
  ReactionDef(
    type: 'LIKE',
    label: 'Like',
    icon: CustomPaint(painter: LikePainter(), size: const Size(24, 24)),
    color: const Color(0xFF1b74e4),
  ),
  ReactionDef(
    type: 'LOVE',
    label: 'Love',
    icon: CustomPaint(painter: HeartPainter(), size: const Size(24, 24)),
    color: const Color(0xFFf33e58),
  ),
  ReactionDef(
    type: 'AWW',
    label: 'Aww',
    icon: CustomPaint(
      painter: FacePainter(const Color(0xFFf7b125), (c, s) {
        c.drawArc(
          Rect.fromLTRB(
            s.width * 0.3,
            s.width * 0.5,
            s.width * 0.7,
            s.width * 0.75,
          ),
          0,
          3.14,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF895311),
        );
        c.drawCircle(
          Offset(s.width * 0.35, s.height * 0.4),
          s.width * 0.1,
          Paint()..color = const Color(0xFFf33e58),
        );
        c.drawCircle(
          Offset(s.width * 0.65, s.height * 0.4),
          s.width * 0.1,
          Paint()..color = const Color(0xFFf33e58),
        );
      }),
      size: const Size(24, 24),
    ),
    color: const Color(0xFFf7b125),
  ),
  ReactionDef(
    type: 'HAHA',
    label: 'Haha',
    icon: CustomPaint(
      painter: FacePainter(const Color(0xFFf7b125), (c, s) {
        final p = Path()
          ..moveTo(s.width * 0.25, s.height * 0.58)
          ..cubicTo(
            s.width * 0.35,
            s.height * 0.75,
            s.width * 0.65,
            s.height * 0.75,
            s.width * 0.75,
            s.height * 0.58,
          )
          ..close();
        c.drawPath(p, Paint()..color = const Color(0xFF895311));
        c.drawLine(
          Offset(s.width * 0.3, s.height * 0.4),
          Offset(s.width * 0.4, s.height * 0.35),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF895311),
        );
        c.drawLine(
          Offset(s.width * 0.7, s.height * 0.4),
          Offset(s.width * 0.6, s.height * 0.35),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF895311),
        );
      }),
      size: const Size(24, 24),
    ),
    color: const Color(0xFFf7b125),
  ),
  ReactionDef(
    type: 'WOW',
    label: 'Wow',
    icon: CustomPaint(
      painter: FacePainter(const Color(0xFFf7b125), (c, s) {
        c.drawCircle(
          Offset(s.width * 0.5, s.height * 0.65),
          s.width * 0.12,
          Paint()..color = const Color(0xFF895311),
        );
        c.drawCircle(
          Offset(s.width * 0.35, s.height * 0.4),
          s.width * 0.08,
          Paint()..color = const Color(0xFF895311),
        );
        c.drawCircle(
          Offset(s.width * 0.65, s.height * 0.4),
          s.width * 0.08,
          Paint()..color = const Color(0xFF895311),
        );
      }),
      size: const Size(24, 24),
    ),
    color: const Color(0xFFf7b125),
  ),
  ReactionDef(
    type: 'SAD',
    label: 'Sad',
    icon: CustomPaint(
      painter: FacePainter(const Color(0xFFf7b125), (c, s) {
        c.drawArc(
          Rect.fromLTRB(
            s.width * 0.3,
            s.width * 0.6,
            s.width * 0.7,
            s.width * 0.8,
          ),
          3.14,
          3.14,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF895311),
        );
        c.drawLine(
          Offset(s.width * 0.3, s.height * 0.35),
          Offset(s.width * 0.4, s.height * 0.4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF895311),
        );
        c.drawLine(
          Offset(s.width * 0.7, s.height * 0.35),
          Offset(s.width * 0.6, s.height * 0.4),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF895311),
        );
        c.drawCircle(
          Offset(s.width * 0.35, s.height * 0.55),
          s.width * 0.05,
          Paint()..color = const Color(0xFF42a5f5),
        );
      }),
      size: const Size(24, 24),
    ),
    color: const Color(0xFFf7b125),
  ),
  ReactionDef(
    type: 'ANGRY',
    label: 'Angry',
    icon: CustomPaint(
      painter: FacePainter(const Color(0xFFe95c37), (c, s) {
        c.drawLine(
          Offset(s.width * 0.25, s.height * 0.65),
          Offset(s.width * 0.75, s.height * 0.65),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF682006),
        );
        c.drawLine(
          Offset(s.width * 0.25, s.height * 0.35),
          Offset(s.width * 0.45, s.height * 0.45),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF682006),
        );
        c.drawLine(
          Offset(s.width * 0.75, s.height * 0.35),
          Offset(s.width * 0.55, s.height * 0.45),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = const Color(0xFF682006),
        );
        c.drawCircle(
          Offset(s.width * 0.35, s.height * 0.45),
          s.width * 0.06,
          Paint()..color = const Color(0xFF682006),
        );
        c.drawCircle(
          Offset(s.width * 0.65, s.height * 0.45),
          s.width * 0.06,
          Paint()..color = const Color(0xFF682006),
        );
      }),
      size: const Size(24, 24),
    ),
    color: const Color(0xFFe95c37),
  ),
];

ReactionDef? reactionDefFor(String? type) {
  if (type == null || type.isEmpty) return null;
  for (final r in reactions) {
    if (r.type == type) return r;
  }
  return null;
}

class ReactionControl extends StatefulWidget {
  final String? viewerReaction;
  final ValueChanged<String?> onReact;
  final Color? inactiveColor;

  const ReactionControl({
    super.key,
    required this.viewerReaction,
    required this.onReact,
    this.inactiveColor,
  });

  @override
  State<ReactionControl> createState() => _ReactionControlState();
}

class _ReactionControlState extends State<ReactionControl> {
  OverlayEntry? _overlayEntry;

  void _showTray(BuildContext context) {
    if (_overlayEntry != null) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _hideTray,
            ),
          ),
          Positioned(
            left: offset.dx,
            top: offset.dy - 60,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions.map((r) {
                    return _ReactionIcon(
                      reaction: r,
                      onSelect: () {
                        widget.onReact(r.type);
                        _hideTray();
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideTray() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _handleTap() {
    if (widget.viewerReaction != null) {
      widget.onReact(null);
    } else {
      widget.onReact('LIKE');
    }
  }

  @override
  void dispose() {
    _hideTray();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = reactionDefFor(widget.viewerReaction);
    final color =
        active?.color ??
        widget.inactiveColor ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final Widget icon =
        active?.icon ?? Icon(Icons.thumb_up_outlined, size: 18, color: color);
    final label = active?.label ?? 'Like';

    return GestureDetector(
      onLongPress: () => _showTray(context),
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: active != null ? FontWeight.bold : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionIcon extends StatefulWidget {
  final ReactionDef reaction;
  final VoidCallback onSelect;

  const _ReactionIcon({required this.reaction, required this.onSelect});

  @override
  State<_ReactionIcon> createState() => _ReactionIconState();
}

class _ReactionIconState extends State<_ReactionIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onSelect,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()
            ..scaleByDouble(
              _isHovered ? 1.3 : 1.0,
              _isHovered ? 1.3 : 1.0,
              1.0,
              1.0,
            ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(child: widget.reaction.icon),
          ),
        ),
      ),
    );
  }
}
