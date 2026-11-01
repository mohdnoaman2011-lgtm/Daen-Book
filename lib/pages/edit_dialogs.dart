import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

/// يفتح منتقي التاريخ (لا يسمح بتاريخ بعد اليوم).
Future<DateTime?> pickDate(BuildContext context, DateTime initial) {
  final now = DateTime.now();
  final init = initial.isAfter(now) ? now : initial;
  return showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime(2000),
    lastDate: now,
    locale: const Locale('ar'),
  );
}

/// حقل يعرض تاريخًا ويفتح المنتقي عند الضغط.
class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.date, required this.onChanged});
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: ts(context, size: 14, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final d = await pickDate(context, date);
          if (d != null) onChanged(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.line),
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined, size: 18, color: p.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(fmtDateFull(date), style: ts(context, size: 16))),
            if (isToday) Text('اليوم', style: ts(context, size: 13, weight: FontWeight.w700, color: p.accent)),
          ]),
        ),
      ),
    ]);
  }
}

/// اختيار طريقة الدفع: نقدًا / تحويل.
class MethodChips extends StatelessWidget {
  const MethodChips({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('طريقة الدفع', style: ts(context, size: 14, weight: FontWeight.w600)),
      const SizedBox(height: 8),
      Wrap(spacing: 10, children: [
        for (final m in kMethods)
          ChoiceChip(
            label: Text(m, style: ts(context, size: 14, weight: FontWeight.w700, color: value == m ? p.accentInk : p.ink)),
            selected: value == m,
            selectedColor: p.accent,
            backgroundColor: p.surface,
            showCheckmark: false,
            side: BorderSide(color: value == m ? p.accent : p.line),
            onSelected: (_) => onChanged(m),
          ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- تعديل عملية شراء

Future<void> showEditPurchase(BuildContext context, DebtStore store, Creditor c, int index) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PurchaseDialog(store: store, c: c, index: index),
  );
}

class _PurchaseDialog extends StatefulWidget {
  const _PurchaseDialog({required this.store, required this.c, required this.index});
  final DebtStore store;
  final Creditor c;
  final int index;

  @override
  State<_PurchaseDialog> createState() => _PurchaseDialogState();
}

class _PurchaseDialogState extends State<_PurchaseDialog> {
  late final TextEditingController _product;
  late final TextEditingController _price;
  late final TextEditingController _qty;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final x = widget.c.purchases[widget.index];
    _product = TextEditingController(text: x.product);
    _price = TextEditingController(text: fmt(x.price).replaceAll(',', ''));
    _qty = TextEditingController(text: fmt(x.qty).replaceAll(',', ''));
    _date = x.date;
  }

  @override
  void dispose() {
    _product.dispose();
    _price.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _save() {
    final price = parseNum(_price.text);
    final qty = parseNum(_qty.text);
    if (_product.text.trim().isEmpty || price == null || price <= 0 || qty == null || qty <= 0) {
      toast(context, 'أكمل المنتج والسعر والكمية');
      return;
    }
    widget.store.editPurchase(
      widget.c,
      widget.index,
      Purchase(product: _product.text.trim(), price: price, qty: qty, date: _date),
    );
    toast(context, 'تم تعديل العملية');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AlertDialog(
      backgroundColor: p.surface,
      title: Text('تعديل عملية شراء', style: ts(context, size: 18, weight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LabeledField(label: 'المنتج', controller: _product),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: LabeledField(label: 'السعر', controller: _price, number: true)),
            const SizedBox(width: 10),
            Expanded(child: LabeledField(label: 'الكمية', controller: _qty, number: true)),
          ]),
          const SizedBox(height: 14),
          DateField(label: 'تاريخ الشراء', date: _date, onChanged: (d) => setState(() => _date = d)),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إلغاء', style: ts(context, size: 14, weight: FontWeight.w700, color: p.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentInk),
          onPressed: _save,
          child: Text('حفظ', style: ts(context, size: 14, weight: FontWeight.w700, color: p.accentInk)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- تعديل دفعة

Future<void> showEditPayment(BuildContext context, DebtStore store, Creditor c, int index) {
  return showDialog<void>(
    context: context,
    builder: (_) => _PaymentDialog(store: store, c: c, index: index),
  );
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.store, required this.c, required this.index});
  final DebtStore store;
  final Creditor c;
  final int index;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _method;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final x = widget.c.payments[widget.index];
    _amount = TextEditingController(text: fmt(x.amount).replaceAll(',', ''));
    _note = TextEditingController(text: x.note);
    _method = x.method.isEmpty ? kMethods.first : x.method;
    _date = x.date;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseNum(_amount.text);
    if (v == null || v <= 0) {
      toast(context, 'اكتب المبلغ المدفوع');
      return;
    }
    final old = widget.c.payments[widget.index];
    final maxAmt = widget.c.total - (widget.c.paid - old.amount);
    if (v > maxAmt + 0.005) {
      toast(context, 'المبلغ أكبر من المتبقي (${fmt(maxAmt)} $kCurrency)');
      return;
    }
    widget.store.editPayment(
      widget.c,
      widget.index,
      Payment(amount: v, note: _note.text.trim(), method: _method, date: _date),
    );
    toast(context, 'تم تعديل الدفعة');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AlertDialog(
      backgroundColor: p.surface,
      title: Text('تعديل دفعة', style: ts(context, size: 18, weight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          LabeledField(label: 'المبلغ المدفوع', controller: _amount, number: true),
          const SizedBox(height: 14),
          MethodChips(value: _method, onChanged: (m) => setState(() => _method = m)),
          const SizedBox(height: 14),
          LabeledField(label: 'ملاحظة', controller: _note, optional: true),
          const SizedBox(height: 14),
          DateField(label: 'تاريخ الدفعة', date: _date, onChanged: (d) => setState(() => _date = d)),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('إلغاء', style: ts(context, size: 14, weight: FontWeight.w700, color: p.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentInk),
          onPressed: _save,
          child: Text('حفظ', style: ts(context, size: 14, weight: FontWeight.w700, color: p.accentInk)),
        ),
      ],
    );
  }
}
