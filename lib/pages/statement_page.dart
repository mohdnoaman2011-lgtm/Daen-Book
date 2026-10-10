import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models.dart';
import '../report.dart';
import '../store.dart';
import '../ui.dart';

class StatementPage extends StatefulWidget {
  const StatementPage({super.key, required this.store});
  final DebtStore store;

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  final _amount = TextEditingController();
  final _note = TextEditingController();

  DebtStore get store => widget.store;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _payPart(Creditor c) {
    final v = parseNum(_amount.text);
    if (v == null || v <= 0) {
      toast(context, 'اكتب المبلغ المدفوع');
      return;
    }
    if (c.settled) {
      toast(context, 'لا يوجد متبقٍ للسداد');
      return;
    }
    final paid = store.addPayment(c, v, _note.text);
    _amount.clear();
    _note.clear();
    FocusScope.of(context).unfocus();
    if (c.settled) {
      _removeIfSettled(c);
    } else {
      toast(context, 'تم تسجيل دفعة ${fmt(paid)} $kCurrency');
    }
  }

  /// عند اكتمال السداد يُحذف الدائن من جميع السجلات (مع زر «تراجع» لبضع ثوانٍ).
  void _removeIfSettled(Creditor c) {
    if (!c.settled) return;
    final name = c.name;
    store.removeCreditor(c.id);
    toast(
      context,
      'تم السداد الكامل وحُذف $name من جميع السجلات',
      actionLabel: 'تراجع',
      onAction: store.undoRemove,
    );
  }

  void _payAll(Creditor c) {
    store.addPayment(c, c.remaining, 'سداد كامل');
    _amount.clear();
    _note.clear();
    FocusScope.of(context).unfocus();
    _removeIfSettled(c);
  }

  Future<void> _savePdf(Creditor c) async {
    try {
      final bytes = await buildStatementPdf(c);
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: 'statement_${c.id}.pdf');
    } catch (e) {
      if (mounted) toast(context, 'تعذر إنشاء التقرير. تأكد من الاتصال بالإنترنت لأول مرة (تحميل الخط).');
    }
  }

  Future<void> _share(Creditor c) async {
    try {
      final bytes = await buildStatementPdf(c);
      await Printing.sharePdf(bytes: bytes, filename: 'statement_${c.id}.pdf');
    } catch (e) {
      if (mounted) toast(context, 'تعذرت المشاركة');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final c = store.selected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const ScreenHeader('كشف حساب الدائن', 'سدّد دفعة أو راجع المشتريات والمدفوعات'),
        const SizedBox(height: 16),
        if (c == null)
          AppCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Center(child: Text('لا يوجد دائنون مسجلون. أضف مشتريات أولًا.', style: ts(context, size: 15, color: p.muted))),
          )
        else ...[
          Text('اختر الدائن', style: ts(context, size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: c.id,
            isExpanded: true,
            items: [
              for (final x in store.creditors)
                DropdownMenuItem(value: x.id, child: Text(x.name, style: ts(context, size: 16))),
            ],
            onChanged: (v) {
              if (v != null) store.select(v);
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

          // ---- دفع جزء من المبلغ
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('دفع جزء من المبلغ', style: ts(context, size: 17, weight: FontWeight.w700)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(12)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('المتبقي الحالي', style: ts(context, size: 14, color: p.muted)),
                  Money(c.remaining, size: 20, color: c.settled ? p.ok : p.debt),
                ]),
              ),
              const SizedBox(height: 14),
              LabeledField(label: 'المبلغ المدفوع', hint: '0', controller: _amount, number: true),
              const SizedBox(height: 14),
              LabeledField(label: 'ملاحظة', hint: 'مثال: دفعة نقدًا', controller: _note, optional: true),
              const SizedBox(height: 14),
              Btn('تسجيل الدفعة', onPressed: () => _payPart(c)),
              const SizedBox(height: 10),
              Btn('سداد المتبقي بالكامل', kind: BtnKind.outline, onPressed: () => _payAll(c)),
            ]),
          ),
          const SizedBox(height: 16),

          // ---- كشف الحساب
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('كشف حساب', style: ts(context, size: 17, weight: FontWeight.w700)),
                Flexible(child: Text(c.name, overflow: TextOverflow.ellipsis, style: ts(context, size: 14, weight: FontWeight.w600, color: p.muted))),
              ]),
              const SizedBox(height: 12),
              _PurchasesTable(c: c),
              if (c.payments.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('الدفعات', style: ts(context, size: 13, weight: FontWeight.w700, color: p.muted)),
                const SizedBox(height: 6),
                for (final y in c.payments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Flexible(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '${fmtDate(y.date)}  ', style: ts(context, size: 13, color: p.muted)),
                          TextSpan(text: y.note, style: ts(context, size: 13)),
                        ])),
                      ),
                      Text('− ${fmt(y.amount)}', style: ts(context, size: 13, weight: FontWeight.w700, color: p.ok)),
                    ]),
                  ),
              ],
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: p.surface2, borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  _SumRow('إجمالي المشتريات', Money(c.total, size: 14, color: p.ink, weight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  _SumRow('إجمالي المدفوع', Money(c.paid, size: 14, color: p.ok, weight: FontWeight.w700)),
                  Divider(height: 20, color: p.line),
                  _SumRow('المتبقي على الدائن', Money(c.remaining, size: 16, color: c.settled ? p.ok : p.debt), bold: true),
                ]),
              ),
              const SizedBox(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('خط نسبة السداد', style: ts(context, size: 13, color: p.muted)),
                Text('${c.percent}%', style: ts(context, size: 13, weight: FontWeight.w800)),
              ]),
              const SizedBox(height: 8),
              ProgressBar(c.percent, height: 12),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('0%', style: ts(context, size: 11, color: p.muted)),
                Text('50%', style: ts(context, size: 11, color: p.muted)),
                Text('100%', style: ts(context, size: 11, color: p.muted)),
              ]),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: Btn('حفظ التقرير PDF', kind: BtnKind.red, icon: Icons.download, height: 50, onPressed: () => _savePdf(c))),
                const SizedBox(width: 10),
                Expanded(child: Btn('مشاركة', kind: BtnKind.ghost, icon: Icons.share, height: 50, onPressed: () => _share(c))),
              ]),
            ]),
          ),
        ],
      ],
    );
  }
}

class _SumRow extends StatelessWidget {
  const _SumRow(this.label, this.value, {this.bold = false});
  final String label;
  final Widget value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: ts(context, size: 14, weight: bold ? FontWeight.w700 : FontWeight.w400, color: bold ? p.ink : p.muted)),
      value,
    ]);
  }
}

class _PurchasesTable extends StatelessWidget {
  const _PurchasesTable({required this.c});
  final Creditor c;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    // الرؤوس والأرقام تتقلص تلقائيًا بدل أن تنكسر على سطرين.
    Widget cell(String t, {bool head = false, bool bold = false, Color? color, bool fit = false}) {
      final text = Text(t,
          maxLines: (head || fit) ? 1 : null,
          style: ts(context,
              size: head ? 12 : 13,
              weight: head || bold ? FontWeight.w700 : FontWeight.w400,
              color: color ?? (head ? p.muted : p.ink)));
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 3),
        child: (head || fit)
            ? FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: text)
            : text,
      );
    }

    if (c.purchases.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(child: Text('لا توجد مشتريات مسجلة', style: ts(context, size: 13, color: p.muted))),
      );
    }

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(48),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(56),
        3: FixedColumnWidth(46),
        4: FixedColumnWidth(62),
      },
      border: TableBorder(horizontalInside: BorderSide(color: p.line)),
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line, width: 2))),
          children: [
            cell('الشهر', head: true),
            cell('المنتج', head: true),
            cell('السعر', head: true),
            cell('الكمية', head: true),
            cell('الإجمالي', head: true),
          ],
        ),
        for (final x in c.purchases)
          TableRow(children: [
            cell(monthName(x.date.month), color: p.muted, fit: true),
            cell(x.product, bold: true),
            cell(fmt(x.price), fit: true),
            cell(fmt(x.qty), fit: true),
            cell(fmt(x.total), bold: true, fit: true),
          ]),
      ],
    );
  }
}