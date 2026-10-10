import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.store});
  final DebtStore store;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final rows = store.sorted;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const ScreenHeader('دفتر الديون', 'ملخص حساباتك مع الدائنين'),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Stat('عدد الدائنين المسجلين', child: Text('${store.creditors.length}', style: ts(context, size: 26, weight: FontWeight.w800)))),
            const SizedBox(width: 12),
            Expanded(child: _Stat('إجمالي الديون', child: Money(store.totalDebt))),
          ]),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _Stat('المسدد', child: Money(store.totalPaid, color: p.ok))),
            const SizedBox(width: 12),
            Expanded(
              child: _Stat('المتبقي',
                  filled: true,
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: fmt(store.totalRemaining), style: ts(context, size: 22, weight: FontWeight.w800, color: p.accentInk)),
                    TextSpan(text: ' $kCurrency', style: ts(context, size: 12, weight: FontWeight.w600, color: p.accentInk)),
                  ]))),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          radius: 16,
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('نسبة السداد الإجمالية', style: ts(context, size: 13, color: p.muted)),
              Text('${store.overallPercent}%', style: ts(context, size: 13, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            ProgressBar(store.overallPercent),
          ]),
        ),
        const SizedBox(height: 20),
        Text('الدائنون — الأكبر دينًا أولًا', style: ts(context, size: 17, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          AppCard(
            radius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
            child: Column(children: [
              Text('لا يوجد دائنون بعد', style: ts(context, size: 16, weight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('سجّل أول عملية شراء ليظهر الدائن هنا.', style: ts(context, size: 14, color: p.muted)),
              const SizedBox(height: 14),
              Btn('تسجيل مشتريات', height: 48, onPressed: () => store.setTab(1)),
            ]),
          )
        else
          for (var i = 0; i < rows.length; i++) ...[
            _CreditorRow(rank: i + 1, c: rows[i], onTap: () => store.openStatement(rows[i].id)),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, {required this.child, this.filled = false});
  final String label;
  final Widget child;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return AppCard(
      radius: 16,
      color: filled ? p.accent : null,
      borderColor: filled ? p.accent : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: ts(context, size: 13, color: filled ? p.accentInk : p.muted)),
        const SizedBox(height: 4),
        child,
      ]),
    );
  }
}

class _CreditorRow extends StatelessWidget {
  const _CreditorRow({required this.rank, required this.c, required this.onTap});
  final int rank;
  final Creditor c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.surface2, shape: BoxShape.circle),
              child: Text('$rank', style: ts(context, size: 15, weight: FontWeight.w800, color: p.accent)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: ts(context, size: 16, weight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: ProgressBar(c.percent, height: 6)),
                  const SizedBox(width: 8),
                  Text('${c.percent}%', style: ts(context, size: 12, color: p.muted)),
                ]),
              ]),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(c.settled ? 'مسدد' : fmt(c.remaining),
                  style: ts(context, size: 17, weight: FontWeight.w800, color: c.settled ? p.ok : p.debt)),
              Text(c.settled ? 'لا دين' : 'متبقي $kCurrency', style: ts(context, size: 12, color: p.muted)),
            ]),
          ]),
        ),
      ),
    );
  }
}
