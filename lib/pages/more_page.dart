import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../backup.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';
import 'lock_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.store});
  final DebtStore store;

  Future<bool> _confirm(BuildContext context, String title, String body, String yes) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: ts(ctx, size: 18, weight: FontWeight.w700)),
        content: Text(body, style: ts(ctx, size: 14, height: 1.6)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('إلغاء', style: ts(ctx, size: 15, weight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(yes, style: ts(ctx, size: 15, weight: FontWeight.w700, color: Pal.of(ctx).debt))),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _backup(BuildContext context) => runBackup(context, store);

  /// قائمة النسخ التلقائية الأسبوعية المحفوظة داخل التطبيق.
  Future<void> _autoBackups(BuildContext context) async {
    final files = await store.listAutoBackups();
    if (!context.mounted) return;
    final p = Pal.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.surface,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('النسخ التلقائية', style: ts(ctx, size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('تُحفظ تلقائيًا كل أسبوع داخل التطبيق (آخر 5 نسخ). تُحذف إن حُذف التطبيق، فاحفظ نسخة خارجية أيضًا.',
                style: ts(ctx, size: 13, color: p.muted, height: 1.6)),
            const SizedBox(height: 10),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('لا توجد نسخ تلقائية بعد. تُنشأ أول نسخة عند أول فتح بعد أسبوع.',
                    style: ts(ctx, size: 14, color: p.muted)),
              )
            else
              for (final f in files)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history, color: p.accent),
                  title: Text(
                    f.path.split('/').last.replaceFirst('auto_', '').replaceFirst('.json', ''),
                    style: ts(ctx, size: 15, weight: FontWeight.w700),
                  ),
                  trailing: Text('استعادة', style: ts(ctx, size: 14, weight: FontWeight.w700, color: p.accent)),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _restoreAuto(context, f);
                  },
                ),
          ]),
        ),
      ),
    );
  }

  Future<void> _restoreAuto(BuildContext context, File f) async {
    try {
      final raw = await f.readAsString();
      if (!context.mounted) return;
      final ok = await _confirm(context, 'استعادة نسخة تلقائية', 'ستُستبدل البيانات الحالية بمحتوى هذه النسخة.', 'استعادة');
      if (!ok) return;
      store.importJson(raw);
      if (context.mounted) toast(context, 'تمت استعادة البيانات');
    } catch (_) {
      if (context.mounted) toast(context, 'تعذرت استعادة النسخة');
    }
  }

  Future<void> _togglePin(BuildContext context, bool on) async {
    if (on) {
      final ok = await showPinSetupDialog(context, store);
      if (ok && context.mounted) toast(context, 'تم تفعيل قفل التطبيق');
    } else {
      final ok = await showPinVerifyDialog(context, store);
      if (ok) {
        await store.clearPin();
        if (context.mounted) toast(context, 'تم إلغاء قفل التطبيق');
      }
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final ok = await showPinVerifyDialog(context, store);
    if (ok && context.mounted) {
      final done = await showPinSetupDialog(context, store);
      if (done && context.mounted) toast(context, 'تم تغيير الرمز');
    }
  }

  Future<void> _restore(BuildContext context) async {
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
      if (res == null || res.files.single.bytes == null) return;
      final raw = utf8.decode(res.files.single.bytes!);
      if (!context.mounted) return;
      final ok = await _confirm(context, 'استعادة نسخة احتياطية', 'ستُستبدل البيانات الحالية بمحتوى النسخة المختارة.', 'استعادة');
      if (!ok) return;
      store.importJson(raw);
      if (context.mounted) toast(context, 'تمت استعادة البيانات');
    } catch (_) {
      if (context.mounted) toast(context, 'الملف غير صالح');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final dark = store.themeMode == ThemeMode.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        const ScreenHeader('المزيد'),
        const SizedBox(height: 16),

        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('النسخ الاحتياطي', style: ts(context, size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('بياناتك محفوظة على هذا الهاتف فقط. احفظ نسخة احتياطية بشكل دوري وخزّنها خارج الهاتف.',
                style: ts(context, size: 14, color: p.muted, height: 1.7)),
            const SizedBox(height: 12),
            Text(
              store.lastBackup == null
                  ? 'آخر نسخة احتياطية: لم تُؤخذ بعد'
                  : 'آخر نسخة احتياطية: ${fmtDateFull(store.lastBackup!)} (${store.daysSinceBackup == 0 ? 'اليوم' : 'قبل ${store.daysSinceBackup} يومًا'})',
              style: ts(context, size: 13, weight: FontWeight.w700, color: store.backupDue || store.lastBackup == null ? p.debt : p.ok),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Btn('نسخة احتياطية', height: 50, onPressed: () => _backup(context))),
              const SizedBox(width: 10),
              Expanded(child: Btn('استعادة', kind: BtnKind.outline, height: 50, onPressed: () => _restore(context))),
            ]),
            const SizedBox(height: 10),
            Btn('النسخ التلقائية الأسبوعية', kind: BtnKind.ghost, icon: Icons.history, height: 46, onPressed: () => _autoBackups(context)),
          ]),
        ),
        const SizedBox(height: 16),

        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الأمان', style: ts(context, size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('قفل التطبيق برمز', style: ts(context, size: 15, weight: FontWeight.w600)),
              Switch(
                value: store.pinEnabled,
                onChanged: (v) => _togglePin(context, v),
                thumbColor: WidgetStatePropertyAll(store.pinEnabled ? p.accent : p.muted),
                trackColor: WidgetStatePropertyAll(
                    store.pinEnabled ? p.accent.withOpacity(0.4) : p.track),
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ]),
            const SizedBox(height: 6),
            Text('يُطلب الرمز عند فتح التطبيق وبعد البقاء خارجه دقيقة أو أكثر.',
                style: ts(context, size: 13, color: p.muted, height: 1.6)),
            if (store.pinEnabled) ...[
              const SizedBox(height: 10),
              Btn('تغيير الرمز', kind: BtnKind.ghost, height: 44, onPressed: () => _changePin(context)),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('المظهر', style: ts(context, size: 17, weight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('الوضع الداكن', style: ts(context, size: 15, weight: FontWeight.w600)),
              Switch(
                value: dark,
                onChanged: (v) => store.setDark(v),
                thumbColor: WidgetStatePropertyAll(dark ? p.accent : p.muted),
                trackColor: WidgetStatePropertyAll(
                    dark ? p.accent.withOpacity(0.4) : p.track),
                trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
                thumbIcon: const WidgetStatePropertyAll(null),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        AppCard(
          color: p.dangerBg,
          borderColor: p.debt,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('منطقة الخطر', style: ts(context, size: 17, weight: FontWeight.w700, color: p.debt)),
            const SizedBox(height: 10),
            Text('يحذف كل المشتريات والدفعات نهائيًا. يُنصح بأخذ نسخة احتياطية أولًا.',
                style: ts(context, size: 14, height: 1.7)),
            const SizedBox(height: 12),
            Btn('تفريغ كل البيانات', kind: BtnKind.danger, height: 50, onPressed: () async {
              final ok = await _confirm(context, 'تفريغ كل البيانات', 'هل أنت متأكد؟ لا يمكن التراجع عن هذا الإجراء.', 'نعم، احذف الكل');
              if (ok) {
                store.clearAll();
                if (context.mounted) toast(context, 'تم تفريغ كل البيانات');
              }
            }),
          ]),
        ),
      ],
    );
  }
}
