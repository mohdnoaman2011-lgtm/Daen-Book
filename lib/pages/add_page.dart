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
  final _search = TextEditingController();
  bool _newMode = false;
  int _month = DateTime.now().month;

  DebtStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    _price.addListener(() => setState(() {}));
    _qty.addListener(() => setState(() {}));
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _product.dispose();
    _price.dispose();
    _qty.dispose();
    _search.dispose();
    super.dispose();
  }

  bool get _isNew => _newMode || store.creditors.isEmpty;

  /// توحيد الحروف العربية لتسهيل البحث (أ إ آ ← ا، ة ← ه، ى ← ي، وإزالة التشكيل).
  String _norm(String s) {
    return s
        .replaceAll(RegExp('[\u064B-\u0652\u0640]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  /// الأكثر تعاملًا أولًا (عدد المشتريات + الدفعات)، ثم الأكبر إجماليًا،
  /// مع تصفية الأسماء حسب نص البحث.
  List<Creditor> get _sorted {
    final q = _norm(_search.text);
    final l = store.creditors.where((c) => q.isEmpty || _norm(c.name).contains(q)).toList();
    l.sort((a, b) {
      final ca = a.purchases.length + a.payments.length;
      final cb = b.purchases.length + b.payments.length;
      if (cb != ca) return cb.compareTo(ca);
      return b.total.compareTo(a.total);
    });
    return l;
  }

  /// يرجع الدائن الموجود بنفس الاسم (بعد توحيد الحروف)، أو null.
  Creditor? _existing(String name) {
    final n = _norm(name);
    if (n.isEmpty) return null;
    for (final c in store.creditors) {
      if (_norm(c.name) == n) return c;
    }
    return null;
  }

  Future<void> _showDuplicate(Creditor dup) {
    final p = Pal.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: p.debt),
          const SizedBox(width: 8),
          Expanded(child: Text('هذا الاسم موجود مسبقًا', style: ts(context, size: 17, weight: FontWeight.w800))),
        ]),
        content: Text(
          'يوجد دائن باسم «${dup.name}» في السجلات. هل تريد اختياره وإضافة المشتريات إلى حسابه؟',
          style: ts(context, size: 14, color: p.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('تعديل الاسم', style: ts(context, size: 14, weight: FontWeight.w700, color: p.muted)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentInk),
            onPressed: () {
              Navigator.of(ctx).pop();
              store.select(dup.id);
              setState(() {
                _newMode = false;
                _name.clear();
                _search.clear();
              });
            },
            child: Text('اختيار الدائن الموجود', style: ts(context, size: 14, weight: FontWeight.w700, color: p.accentInk)),
          ),
        ],
      ),
    );
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
    if (_isNew) {
      final dup = _existing(_name.text);
      if (dup != null) {
        _showDuplicate(dup);
        return;
      }
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
      _search.clear();
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
    final list = _sorted;
    final searching = _search.text.trim().isNotEmpty;
    OutlineInputBorder border(Color c, [double w = 1]) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c, width: w));

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
        const SizedBox(height: 10),
        if (store.creditors.isNotEmpty) ...[
          TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            style: ts(context, size: 15),
            decoration: InputDecoration(
              hintText: 'ابحث عن اسم الدائن',
              hintStyle: ts(context, size: 14, color: p.muted),
              prefixIcon: Icon(Icons.search, color: p.muted),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close, color: p.muted),
                      tooltip: 'مسح البحث',
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                    ),
              filled: true,
              fillColor: p.surface,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: border(p.line),
              enabledBorder: border(p.line),
              focusedBorder: border(p.accent, 1.6),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _NewAvatar(selected: _isNew, onTap: () => setState(() => _newMode = true)),
            for (final c in list)
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
        if (searching && list.isEmpty) ...[
          const SizedBox(height: 4),
          Text('لا يوجد دائن بهذا الاسم. اضغط «جديد» لإضافته.', style: ts(context, size: 13, color: p.muted)),
        ],
        if (_isNew) ...[
          const SizedBox(height: 10),
          LabeledField(label: 'اسم الدائن الجديد', hint: 'اكتب اسم الدائن', controller: _name),
          if (_existing(_name.text) != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: p.debt),
              const SizedBox(width: 6),
              Expanded(
                child: Text('هذا الاسم موجود مسبقًا في السجلات',
                    style: ts(context, size: 13, weight: FontWeight.w700, color: p.debt)),
              ),
            ]),
          ],
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