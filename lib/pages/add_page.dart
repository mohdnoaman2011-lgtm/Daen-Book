const List<Color> _kAvatarColors = [
  Color(0xFF8B2F45), // وردي داكن
  Color(0xFF1F4E79), // أزرق
  Color(0xFF8A4B0F), // بني
  Color(0xFF5B3F8C), // بنفسجي
  Color(0xFF5E6B1F), // زيتوني
  Color(0xFF0F6B6B), // تركوازي
];

const double _kD = 56; // قطر الدائرة
const double _kRing = 10; // زيادة الحلقة الخارجية
const double _kItemW = 72; // عرض العنصر (الدائرة + الاسم)

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.colorIndex, required this.selected, required this.onTap});
  final String name;
  final int colorIndex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = _kAvatarColors[colorIndex.abs() % _kAvatarColors.length];
    final fg = dark ? HSLColor.fromColor(base).withLightness(0.78).toColor() : base;
    final bg = base.withOpacity(dark ? 0.28 : 0.16);
    final t = name.trim();
    final initial = t.isEmpty ? '؟' : String.fromCharCode(t.runes.first);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: _kItemW,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: _kD + _kRing,
            height: _kD + _kRing,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (selected)
                Container(
                  width: _kD + _kRing,
                  height: _kD + _kRing,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent, width: 2)),
                ),
              Container(
                width: _kD,
                height: _kD,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? p.accent : bg),
                child: Text(initial,
                    style: ts(context, size: 24, weight: FontWeight.w800, color: selected ? p.accentInk : fg)),
              ),
              if (selected)
                PositionedDirectional(
                  end: 2,
                  bottom: 2,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                      border: Border.all(color: p.accent, width: 2),
                    ),
                    child: Icon(Icons.check, size: 14, color: p.accent),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ts(context,
                  size: 13,
                  weight: selected ? FontWeight.w800 : FontWeight.w500,
                  color: selected ? p.accent : p.ink),
            ),
          ),
        ]),
      ),
    );
  }
}

class _NewAvatar extends StatelessWidget {
  const _NewAvatar({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: _kItemW,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: _kD + _kRing,
            height: _kD + _kRing,
            child: Center(
              child: Container(
                width: _kD,
                height: _kD,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? p.accent.withOpacity(0.14) : null,
                ),
                child: CustomPaint(
                  painter: _DashedCircle(p.accent),
                  child: Center(child: Icon(Icons.add, size: 30, color: p.accent)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('جديد',
              style: ts(context, size: 13, weight: selected ? FontWeight.w800 : FontWeight.w600, color: p.accent)),
        ]),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  _DashedCircle(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final path = Path()..addOval(Rect.fromLTWH(1.1, 1.1, size.width - 2.2, size.height - 2.2));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4.5), paint);
        d += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}