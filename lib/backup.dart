import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'store.dart';
import 'ui.dart';

/// ينشئ نسخة احتياطية: حفظ مباشر على الهاتف، وإن تعذّر فمشاركة كملف.
/// يُسجَّل تاريخ آخر نسخة عند النجاح (لتذكير الأسبوع).
Future<void> runBackup(BuildContext context, DebtStore store) async {
  if (store.creditors.isEmpty) {
    toast(context, 'لا توجد بيانات للنسخ');
    return;
  }
  final stamp = DateTime.now().toIso8601String().substring(0, 10);
  final name = 'debt_book_backup_$stamp.json';
  final bytes = Uint8List.fromList(utf8.encode(store.exportJson()));
  // 1) الحفظ مباشرة على الهاتف (يختار المستخدم المجلد).
  try {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية',
      fileName: name,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path != null) {
      await store.markBackup();
      if (context.mounted) toast(context, 'تم حفظ النسخة الاحتياطية');
    }
    return; // حُفظ أو أُلغي الحفظ
  } catch (_) {}
  // 2) إن تعذّر، نحاول المشاركة كملف.
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path, mimeType: 'application/json', name: name)]);
    await store.markBackup();
  } catch (_) {
    if (context.mounted) toast(context, 'تعذر إنشاء النسخة الاحتياطية');
  }
}
