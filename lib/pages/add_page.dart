import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class AddPage extends StatefulWidget {
  const AddPage({super.key, required this.store});
  final DebtStore store;

  @override
  State<AddPage> createState() => _AddPageState();
}

class _AddPageState extends State<AddPage> {
  final _name = TextEditingController();
  final _product = TextEditingController();
  final _price = TextEditingController();
  final _qty = TextEditingController(text: '1');
  bool _newMode = false;
  int _month = DateTime.now().month;

  DebtStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _price.addListener(() => setState(() {}));
    _qty.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _product.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  bool get _isNew => _newMode || store.creditors.isEmpty;

  /// الأكثر تعاملًا أولًا (عدد المشتريات + الدفعات)، ثم الأكبر إجماليًا.
  List<Creditor> get _sorted {
    final l = [...store.creditors];
    l.sort((a, b) {
      final ca = a.purchases.length + a.payments.length;
      final cb = b.purchases.length + b.payments.length;
      if (cb != ca) return cb.compareTo(ca);
      return b.total.compareTo(a.total);
    });
    return l;
  }

  void _submit() {
    final price = parseNum(_price.text);
    final qty = parseNum(_qty.text);
    if (_product.text.trim().isEmpty || price == null || price <= 0 || qty == null || qty <= 0) {
      toast(context, 'أكمل المنتج والسعر والكمية');
      return;
    }
    if (_isNew && _name.text.trim().isEmpty) {
      toast(context, 'اكتب اسم الدائن');
      return;
    }
    final now = DateTime.now();
    final year = _month > now.month ? now.year - 1 : now.year;
    final day = _month == now.month ? now.day : 1;
    final name = store.addPurchase(
      creditorId: store.selected?.id,
      newName: _isNew ? _name.text : null,
      product: _product.text,
      price: price,
      qty: qty,
      date: DateTime(year, _month, day),
    );
    setState(() {
      _month = now.month;
      _newMode = false;
      _name.clear();
      _product.clear();
      _price.clear();
      _qty.text = '1';
    });
    FocusScope.of(context).unfocus();
    toast(context, 'تمت الإضافة إلى حساب $name');
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final selected = store.selected;
    final lineTotal = (parseNum(_price.text) ?? 0) * (parseNum(_qty.text) ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const ScreenHeader('تسجيل المشتريات', 'أضف مشتريات الآجل إلى حساب الدائن'),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('اسم الدائن', style: ts(context, size: 14, weight: FontWeight.w600)),
          if (store.creditors.length > 1)
            Text('الأكثر تعاملًا أولًا', style: ts(context, size: 13, weight: FontWeight.w600, color: p.accent)),
        ]),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _NewAvatar(selected: _isNew, onTap: () => setState(() => _newMode = true)),
            for (final c in _sorted)
              _Avatar(
                name: c.name,
                colorIndex: c.id,
                selected: !_isNew && selected?.id == c.id,
                onTap: () {
                  store.select(c.id);
                  setState(() => _newMode = false);
                },
              ),
          ]),
        ),
        if (_isNew) ...[
          const SizedBox(height: 10),
          LabeledField(label: 'اسم الدائن الجديد', hint: 'اكتب اسم الدائن', controller: _name),
        ] else if (selected != null) ...[
          const SizedBox(height: 8),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'الرصيد الحالي عليه: ', style: ts(context, size: 13, color: p.muted)),
            TextSpan(text: '${fmt(selected.remaining)} $kCurrency', style: ts(context, size: 13, weight: FontWeight.w700, color: p.debt)),
          ])),
        ],
        const SizedBox(height: 16),
        LabeledField(label: 'المنتج', hint: 'مثال: سكر، زيت، دقيق', controller: _product),
        const SizedBox(height: 16),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: LabeledField(label: 'السعر', hint: '0', controller: _price, number: true)),
          const SizedBox(width: 12),
          Expanded(child: LabeledField(label: 'الكمية', hint: '1', controller: _qty, number: true)),
        ]),
        const SizedBox(height: 16),
        Text('شهر الشراء', style: ts(context, size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _month,
          isExpanded: true,
          items: [
            for (var m = 1; m <= 12; m++)
              DropdownMenuItem(value: m, child: Text(monthName(m), style: ts(context, size: 16))),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _month = v);
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line)),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('إجمالي هذه العملية', style: ts(context, size: 14, color: p.muted)),
            Money(lineTotal, size: 20),
          ]),
        ),
        const SizedBox(height: 16),
        Btn('إضافة إلى حساب الدائن', height: 54, onPressed: _submit),
      ],
    );
  }
}

const List<Color> _kAvatarColors = [
  Color(0xFF8B2F45), // وردي داكن
  Color(0xFF1F4E79), // أزرق
  Color(0xFF8A4B0F), // بني
  Color(0xFF5B3F8C), // بنفسجي
  Color(0xFF5E6B1F), // زيتوني
  Color(0xFF0F6B6B), // تركوازي
];

const double _kD = 66; // قطر الدائرة

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
        width: 86,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: _kD + 12,
            height: _kD + 12,
            child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (selected)
                Container(
                  width: _kD + 12,
                  height: _kD + 12,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.accent, width: 2.5)),
                ),
              Container(
                width: _kD,
                height: _kD,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? p.accent : bg),
                child: Text(initial,
                    style: ts(context, size: 28, weight: FontWeight.w800, color: selected ? p.accentInk : fg)),
              ),
              if (selected)
                PositionedDirectional(
                  end: 2,
                  bottom: 2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                      border: Border.all(color: p.accent, width: 2),
                    ),
                    child: Icon(Icons.check, size: 16, color: p.accent),
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
                  size: 14,
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
        width: 86,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: _kD + 12,
            height: _kD + 12,
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
                  child: Center(child: Icon(Icons.add, size: 34, color: p.accent)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('جديد',
              style: ts(context, size: 14, weight: selected ? FontWeight.w800 : FontWeight.w600, color: p.accent)),
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
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final path = Path()..addOval(Rect.fromLTWH(1.3, 1.3, size.width - 2.6, size.height - 2.6));
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 5), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}