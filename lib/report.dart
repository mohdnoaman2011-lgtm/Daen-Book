import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
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
  const double k = 3.0; // دقة الصورة
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
      textDirection: TextDirection.rtl,
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
    ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
    [
      for (final p in c.purchases)
        [monthName(p.date.month), p.product, fmt(p.qty), _m(p.price), _m(p.total)],
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
