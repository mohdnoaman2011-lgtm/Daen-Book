import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:pdf/widgets.dart' as pw;
import 'models.dart';

final NumberFormat _money = NumberFormat('#,##0.00', 'en');
String _m(num n) => _money.format(n);
String _d(DateTime d) => DateFormat('dd/MM/yyyy', 'en').format(d);

const Color _teal = Color(0xFF0E6B5B);
const Color _titleColor = Color(0xFF0B4F44);
const Color _headBg = Color(0xFFE6F0EE);
const Color _border = Color(0xFFC5D9D4);
const Color _muted = Color(0xFF5C6863);

/// تقرير كشف حساب الدائن بصيغة PDF (عربي، من اليمين إلى اليسار).
/// الترتيب: العنوان، المشتريات، الدفعات، ثم الإجماليات.
///
/// تُرسم الصفحة بمحرك النصوص الخاص بفلاتر (فتظهر الحروف العربية سليمة تمامًا)
/// ثم تُضمَّن كصورة داخل ملف PDF، فيظهر التقرير نفسه في أي تطبيق لعرض PDF.
Future<Uint8List> buildStatementPdf(Creditor c) async {
  await GoogleFonts.pendingFonts([
    GoogleFonts.cairo(),
    GoogleFonts.cairo(fontWeight: FontWeight.w700),
  ]);

  const double w = 595.0; // عرض A4 بالنقاط
  const double h = 842.0; // ارتفاع A4 بالنقاط
  const double k = 4.0; // دقة الصورة
  const double m = 28.0; // الهامش
  const double cw = w - 2 * m; // عرض المحتوى

  final pictures = <ui.Picture>[];
  ui.PictureRecorder? rec;
  Canvas? cv;
  double y = m + 4;

  void startPage() {
    rec = ui.PictureRecorder();
    cv = Canvas(rec!);
    cv!.scale(k);
    cv!.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFFFFFFF));
    y = m + 4;
  }

  void endPage() {
    pictures.add(rec!.endRecording());
  }

  void ensure(double need) {
    if (y + need > h - m) {
      endPage();
      startPage();
    }
  }

  TextPainter tp(
    String s,
    double size,
    Color color, {
    bool bold = false,
    double width = cw,
    TextAlign align = TextAlign.center,
  }) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: GoogleFonts.cairo(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          height: 1.35,
        ),
      ),
      textDirection: ui.TextDirection.rtl,
      textAlign: align,
    );
    p.layout(minWidth: width, maxWidth: width);
    return p;
  }

  void heading(String s) {
    ensure(26);
    final t = tp(s, 11, Colors.black, bold: true, align: TextAlign.right);
    t.paint(cv!, Offset(m, y));
    y += t.height + 6;
  }

  // العمود الأول (الشهر / التاريخ) في أقصى اليمين.
  void table(List<String> headers, List<List<String>> rows) {
    final n = headers.length;
    final colW = cw / n;

    void row(List<String> cells, {bool head = false}) {
      final size = head ? 9.5 : 11.0;
      var maxH = 0.0;
      for (final s in cells) {
        maxH = math.max(maxH, tp(s, size, Colors.black, width: colW - 10).height);
      }
      final hgt = maxH + 14;
      ensure(hgt);
      for (var i = 0; i < n; i++) {
        final x = m + cw - (i + 1) * colW;
        final r = Rect.fromLTWH(x, y, colW, hgt);
        if (head) cv!.drawRect(r, Paint()..color = _headBg);
        cv!.drawRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.7
            ..color = _border,
        );
        final t = tp(cells[i], size, head ? _muted : Colors.black, width: colW - 10);
        t.paint(cv!, Offset(x + 5, y + (hgt - t.height) / 2));
      }
      y += hgt;
    }

    row(headers, head: true);
    for (final r in rows) {
      row(r);
    }
  }

  void sumRow(String label, String value, {bool last = false}) {
    const hgt = 30.0;
    ensure(hgt);
    final r = Rect.fromLTWH(m, y, cw, hgt);
    if (last) cv!.drawRect(r, Paint()..color = _teal);
    cv!.drawRect(
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = _border,
    );
    final col = last ? Colors.white : Colors.black;
    final a = tp(label, 11, col, bold: last, width: cw - 20, align: TextAlign.right);
    a.paint(cv!, Offset(m + 10, y + (hgt - a.height) / 2));
    final b = tp(value, 11, col, bold: last, width: cw - 20, align: TextAlign.left);
    b.paint(cv!, Offset(m + 10, y + (hgt - b.height) / 2));
    y += hgt;
  }

  startPage();

  // ---- العنوان
  final title = tp('كشف حساب: ${c.name}', 18, _titleColor, bold: true);
  title.paint(cv!, Offset(m, y));
  y += title.height + 22;

  // ---- المشتريات
  heading('المشتريات');
  table(
    ['التاريخ', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
    [
      for (final p in c.purchases)
        [_d(p.date), p.product, fmt(p.qty), _m(p.price), _m(p.total)],
    ],
  );

  // ---- الدفعات
  if (c.payments.isNotEmpty) {
    y += 22;
    heading('الدفعات');
    table(
      ['التاريخ', 'المبلغ', 'ملاحظة'],
      [
        for (final p in c.payments)
          [_d(p.date), _m(p.amount), p.note.isEmpty ? '-' : p.note],
      ],
    );
  }

  // ---- الإجماليات
  y += 22;
  sumRow('إجمالي المشتريات', _m(c.total));
  sumRow('إجمالي المدفوع', _m(c.paid));
  sumRow('المتبقي على الدائن', _m(c.remaining), last: true);

  endPage();

  // ---- تحويل الصفحات إلى PDF
  final doc = pw.Document(title: 'Statement');
  for (final pic in pictures) {
    final img = await pic.toImage((w * k).round(), (h * k).round());
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    final mem = pw.MemoryImage(bd!.buffer.asUint8List());
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Image(mem, fit: pw.BoxFit.fill),
      ),
    );
  }
  return doc.save();
}

/// إيصال استلام دفعة بصيغة PDF (صفحة A5)، يُرسم بنفس طريقة كشف الحساب.
/// [index] ترتيب الدفعة في قائمة دفعات الدائن.
Future<Uint8List> buildReceiptPdf(Creditor c, int index) async {
  await GoogleFonts.pendingFonts([
    GoogleFonts.cairo(),
    GoogleFonts.cairo(fontWeight: FontWeight.w700),
  ]);
  final pay = c.payments[index];
  var paidUpTo = 0.0;
  for (var i = 0; i <= index; i++) {
    paidUpTo += c.payments[i].amount;
  }
  final remainingAfter = math.max(0.0, c.total - paidUpTo);

  const double w = 420.0; // عرض A5 بالنقاط
  const double h = 595.0; // ارتفاع A5 بالنقاط
  const double k = 4.0;
  const double m = 28.0;
  const double cw = w - 2 * m;

  final rec = ui.PictureRecorder();
  final cv = Canvas(rec);
  cv.scale(k);
  cv.drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = const Color(0xFFFFFFFF));
  var y = m;

  TextPainter tp(String s, double size, Color color,
      {bool bold = false, double width = cw, TextAlign align = TextAlign.center}) {
    final p = TextPainter(
      text: TextSpan(
        text: s,
        style: GoogleFonts.cairo(
          fontSize: size,
          color: color,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          height: 1.35,
        ),
      ),
      textDirection: ui.TextDirection.rtl,
      textAlign: align,
    );
    p.layout(minWidth: width, maxWidth: width);
    return p;
  }

  // العنوان
  final title = tp('إيصال استلام دفعة', 20, _titleColor, bold: true);
  title.paint(cv, Offset(m, y));
  y += title.height + 2;
  final sub = tp('دفتر الديون', 11, _muted);
  sub.paint(cv, Offset(m, y));
  y += sub.height + 8;
  cv.drawRect(Rect.fromLTWH(m, y, cw, 1.5), Paint()..color = _teal);
  y += 18;

  // المبلغ المستلم
  const boxH = 78.0;
  final box = RRect.fromRectAndRadius(Rect.fromLTWH(m, y, cw, boxH), const Radius.circular(10));
  cv.drawRRect(box, Paint()..color = _headBg);
  cv.drawRRect(
    box,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _border,
  );
  final l1 = tp('المبلغ المستلم', 11, _muted);
  l1.paint(cv, Offset(m, y + 10));
  final l2 = tp('${_m(pay.amount)} $kCurrency', 24, _titleColor, bold: true);
  l2.paint(cv, Offset(m, y + 10 + l1.height + 2));
  y += boxH + 16;

  // جدول التفاصيل: العنوان على اليمين والقيمة على اليسار
  void row(String label, String value, {bool strong = false}) {
    const labelW = 130.0;
    final valueW = cw - labelW;
    final a = tp(label, 11, strong ? Colors.white : _muted, bold: true, width: labelW - 14, align: TextAlign.right);
    final b = tp(value, 12, strong ? Colors.white : Colors.black, bold: strong, width: valueW - 14, align: TextAlign.right);
    final hgt = math.max(a.height, b.height) + 14;
    final rLabel = Rect.fromLTWH(m + valueW, y, labelW, hgt);
    final rValue = Rect.fromLTWH(m, y, valueW, hgt);
    cv.drawRect(rLabel, Paint()..color = strong ? _teal : _headBg);
    if (strong) cv.drawRect(rValue, Paint()..color = _teal);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = _border;
    cv.drawRect(rLabel, line);
    cv.drawRect(rValue, line);
    a.paint(cv, Offset(rLabel.left + 7, y + (hgt - a.height) / 2));
    b.paint(cv, Offset(rValue.left + 7, y + (hgt - b.height) / 2));
    y += hgt;
  }

  row('الدائن', c.name);
  row('رقم الإيصال', '${c.id}-${index + 1}');
  row('التاريخ', _d(pay.date));
  row('طريقة الدفع', pay.method.isEmpty ? '-' : pay.method);
  if (pay.note.isNotEmpty) row('ملاحظة', pay.note);
  row('إجمالي المشتريات', '${_m(c.total)} $kCurrency');
  row('المدفوع حتى الآن', '${_m(paidUpTo)} $kCurrency');
  row('المتبقي بعد الدفعة', '${_m(remainingAfter)} $kCurrency', strong: true);

  // التوقيع
  y += 46;
  cv.drawRect(Rect.fromLTWH(m, y, 130, 0.8), Paint()..color = Colors.black);
  final sig = tp('توقيع المستلم', 10, _muted, width: 130);
  sig.paint(cv, Offset(m, y + 4));

  final pic = rec.endRecording();
  final img = await pic.toImage((w * k).round(), (h * k).round());
  final bd = await img.toByteData(format: ui.ImageByteFormat.png);
  final mem = pw.MemoryImage(bd!.buffer.asUint8List());
  final doc = pw.Document(title: 'Receipt');
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a5,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Image(mem, fit: pw.BoxFit.fill),
    ),
  );
  return doc.save();
}
