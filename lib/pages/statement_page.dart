import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../models.dart';
import '../report.dart';
import '../store.dart';
import '../ui.dart';
import 'edit_dialogs.dart';

class StatementPage extends StatefulWidget {
  const StatementPage({super.key, required this.store});
  final DebtStore store;

  @override
  State<StatementPage> createState() => _StatementPageState();
}

class _StatementPageState extends State<StatementPage> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _method = kMethods.first;

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
    final paid = store.addPayment(c, v, _note.text, method: _method);
    _amount.clear();
    _note.clear();
    FocusScope.of(context).unfocus();
    _afterPayment(c, paid);
  }

  void _payAll(Creditor c) {
    if (c.settled) {
      toast(context, 'لا يوجد متبقٍ للسداد');
      return;
    }
    final paid = store.addPayment(c, c.remaining, 'سداد كامل', method: _method);
    _amount.clear();
    _note.clear();
    FocusScope.of(context).unfocus();
    _afterPayment(c, paid);
  }

  /// بعد كل دفعة: نافذة تعرض النتيجة مع زرّي الإيصال والمشاركة.
  /// عند اكتمال السداد يُؤرشف الدائن (لا يُحذف) مع زر «تراجع».
  Future<void> _afterPayment(Creditor c, double paid) async {
    final idx = c.payments.length - 1;
    final settled = c.settled;
    final name = c.name;
    final remaining = c.remaining;
    if (settled) store.archiveCreditor(c);
    if (!mounted) return;
    final p = Pal.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.surface,
        title: Row(children: [
          Icon(Icons.check_circle, color: p.ok),
          const SizedBox(width: 8),
          Expanded(child: Text('تم تسجيل الدفعة', style: ts(ctx, size: 18, weight: FontWeight.w800))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${fmt(paid)} $kCurrency من $name', style: ts(ctx, size: 15, weight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            settled ? 'اكتمل السداد، ونُقل الدائن إلى الأرشيف.' : 'المتبقي: ${fmt(remaining)} $kCurrency',
            style: ts(ctx, size: 14, color: p.muted),
          ),
        ]),
        actionsOverflowButtonSpacing: 4,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('إغلاق', style: ts(ctx, size: 14, weight: FontWeight.w700, color: p.muted)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _receipt(c, idx, share: true);
            },
            child: Text('مشاركة الإيصال', style: ts(ctx, size: 14, weight: FontWeight.w700, color: p.accent)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentInk),
            onPressed: () {
              Navigator.of(ctx).pop();
              _receipt(c, idx, share: false);
            },
            child: Text('إيصال PDF', style: ts(ctx, size: 14, weight: FontWeight.w700, color: p.accentInk)),
          ),
        ],
      ),
    );
    if (settled && mounted) {
      toast(context, 'نُقل $name إلى الأرشيف', actionLabel: 'تراجع', onAction: store.undoLast);
    }
  }

  Future<void> _receipt(Creditor c, int idx, {required bool share}) async {
    if (idx < 0 || idx >= c.payments.length) return;
    try {
      final bytes = await buildReceiptPdf(c, idx);
      final name = 'receipt_${c.id}_${idx + 1}.pdf';
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (_) {
      if (mounted) toast(context, 'تعذر إنشاء الإيصال. تأكد من الاتصال بالإنترنت لأول مرة (تحميل الخط).');
    }
  }

  void _deletePurchase(Creditor c, int i) {
    store.deletePurchase(c, i);
    toast(context, 'تم حذف العملية', actionLabel: 'تراجع', onAction: store.undoLast);
  }

  void _deletePayment(Creditor c, int i) {
    store.deletePayment(c, i);
    toast(context, 'تم حذف الدفعة', actionLabel: 'تراجع', onAction: store.undoLast);
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
            child: Center(child: Text(store.creditors.isEmpty ? 'لا يوجد دائنون مسجلون. أضف مشتريات أولًا.' : 'لا يوجد دائنون نشطون. افتح الأرشيف من الشاشة الرئيسية.', textAlign: TextAlign.center, style: ts(context, size: 15, color: p.muted))),
          )
        else ...[
          Text('اختر الدائن', style: ts(context, size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: c.id,
            isExpanded: true,
            items: [
              for (final x in [...store.active, if (c.archived) c])
                DropdownMenuItem(value: x.id, child: Text(c.archived && x.id == c.id ? '${x.name} (مؤرشف)' : x.name, style: ts(context, size: 16))),
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
              MethodChips(value: _method, onChanged: (m) => setState(() => _method = m)),
              const SizedBox(height: 14),
              LabeledField(label: 'ملاحظة', hint: 'مثال: دفعة من الحساب', controller: _note, optional: true),
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
              _PurchasesTable(
                c: c,
                onEdit: (i) => showEditPurchase(context, store, c, i),
                onDelete: (i) => _deletePurchase(c, i),
              ),
              if (c.payments.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('الدفعات', style: ts(context, size: 13, weight: FontWeight.w700, color: p.muted)),
                const SizedBox(height: 6),
                for (var i = 0; i < c.payments.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(
                        child: Text.rich(TextSpan(children: [
                          TextSpan(text: '${fmtDate(c.payments[i].date)}  ', style: ts(context, size: 13, color: p.muted)),
                          if (c.payments[i].method.isNotEmpty)
                            TextSpan(text: '${c.payments[i].method}  ', style: ts(context, size: 12, weight: FontWeight.w700, color: p.accent)),
                          TextSpan(text: c.payments[i].note, style: ts(context, size: 13)),
                        ])),
                      ),
                      Text('− ${fmt(c.payments[i].amount)}', style: ts(context, size: 13, weight: FontWeight.w700, color: p.ok)),
                      _RowMenu(
                        items: const {'receipt': 'إيصال PDF', 'share': 'مشاركة الإيصال', 'edit': 'تعديل', 'delete': 'حذف'},
                        onSelected: (v) {
                          switch (v) {
                            case 'receipt':
                              _receipt(c, i, share: false);
                            case 'share':
                              _receipt(c, i, share: true);
                            case 'edit':
                              showEditPayment(context, store, c, i);
                            case 'delete':
                              _deletePayment(c, i);
                          }
                        },
                      ),
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
              if (c.archived) ...[
                Btn('إعادة الدائن من الأرشيف', kind: BtnKind.outline, height: 48, onPressed: () => store.unarchiveCreditor(c)),
                const SizedBox(height: 10),
              ] else if (c.settled && c.purchases.isNotEmpty) ...[
                Btn('نقل الدائن إلى الأرشيف', kind: BtnKind.outline, height: 48, onPressed: () {
                  final n = c.name;
                  store.archiveCreditor(c);
                  toast(context, 'نُقل $n إلى الأرشيف', actionLabel: 'تراجع', onAction: store.undoLast);
                }),
                const SizedBox(height: 10),
              ],
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

/// قائمة منبثقة صغيرة لكل صف (تعديل / حذف ...).
class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.items, required this.onSelected});
  final Map<String, String> items;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return SizedBox(
      width: 34,
      height: 34,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        icon: Icon(Icons.more_vert, size: 18, color: p.muted),
        color: p.surface,
        onSelected: onSelected,
        itemBuilder: (_) => [
          for (final e in items.entries)
            PopupMenuItem<String>(
              value: e.key,
              child: Text(e.value,
                  style: ts(context, size: 14, weight: FontWeight.w600, color: e.key == 'delete' ? p.debt : null)),
            ),
        ],
      ),
    );
  }
}

class _PurchasesTable extends StatelessWidget {
  const _PurchasesTable({required this.c, required this.onEdit, required this.onDelete});
  final Creditor c;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

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
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: FixedColumnWidth(48),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(56),
        3: FixedColumnWidth(46),
        4: FixedColumnWidth(62),
        5: FixedColumnWidth(34),
      },
      border: TableBorder(horizontalInside: BorderSide(color: p.line)),
      children: [
        TableRow(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line, width: 2))),
          children: [
            cell('التاريخ', head: true),
            cell('المنتج', head: true),
            cell('السعر', head: true),
            cell('الكمية', head: true),
            cell('الإجمالي', head: true),
            const SizedBox(),
          ],
        ),
        for (var i = 0; i < c.purchases.length; i++)
          TableRow(children: [
            cell(fmtDate(c.purchases[i].date), color: p.muted, fit: true),
            cell(c.purchases[i].product, bold: true),
            cell(fmt(c.purchases[i].price), fit: true),
            cell(fmt(c.purchases[i].qty), fit: true),
            cell(fmt(c.purchases[i].total), bold: true, fit: true),
            _RowMenu(
              items: const {'edit': 'تعديل', 'delete': 'حذف'},
              onSelected: (v) => v == 'edit' ? onEdit(i) : onDelete(i),
            ),
          ]),
      ],
    );
  }
}
