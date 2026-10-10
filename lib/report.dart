import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

/// يبني تقرير كشف حساب الدائن بصيغة PDF (عربي، من اليمين إلى اليسار).
/// يستخدم خط Cairo عبر حزمة printing (يتطلب إنترنت أول مرة).
Future<Uint8List> buildStatementPdf(Creditor c) async {
  final regular = await PdfGoogleFonts.cairoRegular();
  final bold = await PdfGoogleFonts.cairoBold();
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regular, bold: bold),
    title: 'كشف حساب ${c.name}',
  );

  pw.Widget kv(String k, String v, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 3),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(k, style: pw.TextStyle(fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(v, style: pw.TextStyle(fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(32),
    build: (ctx) => [
      pw.Text('كشف حساب الدائن', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('${c.name}  —  ${fmtDate(DateTime.now())}', style: const pw.TextStyle(fontSize: 13, color: PdfColors.grey700)),
      pw.SizedBox(height: 18),
      pw.Text('المشتريات', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: ['الشهر', 'المنتج', 'السعر', 'الكمية', 'الإجمالي'],
        data: [
          for (final p in c.purchases)
            [monthName(p.date.month), p.product, fmt(p.price), fmt(p.qty), fmt(p.total)],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
        cellStyle: const pw.TextStyle(fontSize: 11),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
        cellAlignment: pw.Alignment.centerRight,
        headerAlignment: pw.Alignment.centerRight,
        border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
      ),
      if (c.payments.isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text('الدفعات', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: ['التاريخ', 'ملاحظة', 'المبلغ'],
          data: [
            for (final y in c.payments) [fmtDate(y.date), y.note.isEmpty ? '-' : y.note, fmt(y.amount)],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          cellStyle: const pw.TextStyle(fontSize: 11),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
          border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColors.grey300)),
        ),
      ],
      pw.SizedBox(height: 18),
      pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Column(children: [
          kv('إجمالي المشتريات', '${fmt(c.total)} $kCurrency'),
          kv('إجمالي المدفوع', '${fmt(c.paid)} $kCurrency'),
          pw.Divider(color: PdfColors.grey400),
          kv('المتبقي على الدائن', '${fmt(c.remaining)} $kCurrency', strong: true),
        ]),
      ),
      pw.SizedBox(height: 14),
      pw.Text('نسبة السداد: ${c.percent}%', style: const pw.TextStyle(fontSize: 12)),
      pw.SizedBox(height: 4),
      pw.Stack(children: [
        pw.Container(height: 10, decoration: pw.BoxDecoration(color: PdfColors.grey300, borderRadius: pw.BorderRadius.circular(5))),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Container(
            height: 10,
            width: 500 * c.percent / 100,
            decoration: pw.BoxDecoration(color: PdfColors.green700, borderRadius: pw.BorderRadius.circular(5)),
          ),
        ),
      ]),
    ],
  ));

  return doc.save();
}
