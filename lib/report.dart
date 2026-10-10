import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

final NumberFormat _money = NumberFormat('#,##0.00', 'en');
String _m(num n) => _money.format(n);
String _d(DateTime d) => DateFormat('dd/MM/yyyy', 'en').format(d);

const PdfColor _teal = PdfColor.fromInt(0xFF0E6B5B);
const PdfColor _titleColor = PdfColor.fromInt(0xFF0B4F44);
const PdfColor _headBg = PdfColor.fromInt(0xFFE6F0EE);
const PdfColor _border = PdfColor.fromInt(0xFFC5D9D4);
const PdfColor _muted = PdfColor.fromInt(0xFF5C6863);

/// تقرير كشف حساب الدائن بصيغة PDF (عربي، من اليمين إلى اليسار).
/// الترتيب: العنوان، المشتريات، الدفعات، ثم الإجماليات.
/// يستخدم خط Cairo عبر حزمة printing (يتطلب إنترنت أول مرة).
Future<Uint8List> buildStatementPdf(Creditor c) async {
  final regular = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: 'كشف حساب ${c.name}',
  );

  pw.Widget cell(String t, {bool head = false, bool strong = false}) => pw.Container(
        alignment: pw.Alignment.center,
        color: head ? _headBg : null,
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: pw.Text(
          t,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
            fontSize: head ? 9.5 : 11,
            color: head ? _muted : PdfColors.black,
            fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );

  // pw.Table يرتب الأعمدة من اليسار إلى اليمين حتى في الصفحة العربية،
  // لذلك نعكس ترتيب الخلايا ليبدأ الجدول من اليمين (الشهر ... الإجمالي).
  List<String> rtl(List<String> l) => l.reversed.toList();

  pw.Widget grid(List<String> headers, List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: _border, width: 0.7),
        defaultColumnWidth: const pw.FlexColumnWidth(),
        children: [
          pw.TableRow(children: [for (final h in rtl(headers)) cell(h, head: true)]),
          for (final r in rows) pw.TableRow(children: [for (final v in rtl(r)) cell(v)]),
        ],
      );

  pw.Widget heading(String t) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(t, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      );

  pw.TableRow sumRow(String label, String value, {bool last = false}) {
    final color = last ? PdfColors.white : PdfColors.black;
    final w = last ? pw.FontWeight.bold : pw.FontWeight.normal;
    return pw.TableRow(
      decoration: last ? const pw.BoxDecoration(color: _teal) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 9, horizontal: 10),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(label, style: pw.TextStyle(fontSize: 11, color: color, fontWeight: w)),
            pw.Text(value, style: pw.TextStyle(fontSize: 11, color: color, fontWeight: w)),
          ]),
        ),
      ],
    );
  }

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.fromLTRB(28, 32, 28, 32),
    build: (ctx) => [
      pw.Center(
        child: pw.Text(
          'كشف حساب: ${c.name}',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _titleColor),
        ),
      ),
      pw.SizedBox(height: 22),

      heading('المشتريات'),
      grid(
        ['الشهر', 'المنتج', 'الكمية', 'السعر', 'الإجمالي'],
        [
          for (final p in c.purchases)
            [monthName(p.date.month), p.product, fmt(p.qty), _m(p.price), _m(p.total)],
        ],
      ),

      if (c.payments.isNotEmpty) ...[
        pw.SizedBox(height: 22),
        heading('الدفعات'),
        grid(
          ['التاريخ', 'المبلغ', 'ملاحظة'],
          [
            for (final y in c.payments)
              [_d(y.date), _m(y.amount), y.note.isEmpty ? '-' : y.note],
          ],
        ),
      ],

      pw.SizedBox(height: 22),
      pw.Table(
        border: pw.TableBorder.all(color: _border, width: 0.7),
        children: [
          sumRow('إجمالي المشتريات', _m(c.total)),
          sumRow('إجمالي المدفوع', _m(c.paid)),
          sumRow('المتبقي على الدائن', _m(c.remaining), last: true),
        ],
      ),
    ],
  ));

  return doc.save();
}
