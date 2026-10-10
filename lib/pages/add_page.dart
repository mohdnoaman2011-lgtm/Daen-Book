
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
    final name = store.addPurchase(
      creditorId: store.selected?.id,
      newName: _isNew ? _name.text : null,
      product: _product.text,
      price: price,
      qty: qty,
    );
    setState(() {
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
        Text('اسم الدائن', style: ts(context, size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in store.creditors)
            _Chip(
              label: c.name,
              selected: !_isNew && selected?.id == c.id,
              onTap: () {
                store.select(c.id);
                setState(() => _newMode = false);
              },
            ),
          _Chip(label: '+ دائن جديد', selected: _isNew, onTap: () => setState(() => _newMode = true)),
        ]),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: selected ? p.accent : p.surface,
      shape: StadiumBorder(side: BorderSide(color: selected ? p.accent : p.line, width: 2)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: ts(context, size: 15, weight: FontWeight.w700, color: selected ? p.accentInk : p.ink)),
            ]),
          ),
        ),
      ),
    );
  }
}
