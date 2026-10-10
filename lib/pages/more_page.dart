import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../store.dart';
import '../ui.dart';

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

  Future<void> _backup(BuildContext context) async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final file = File('${dir.path}/debt_book_backup_$stamp.json');
      await file.writeAsString(store.exportJson());
      await Share.shareXFiles([XFile(file.path)], text: 'نسخة احتياطية — دفتر الديون');
    } catch (_) {
      if (context.mounted) toast(context, 'تعذر إنشاء النسخة الاحتياطية');
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
            Row(children: [
              Expanded(child: Btn('نسخة احتياطية', height: 50, onPressed: () => _backup(context))),
              const SizedBox(width: 10),
              Expanded(child: Btn('استعادة', kind: BtnKind.outline, height: 50, onPressed: () => _restore(context))),
            ]),
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
