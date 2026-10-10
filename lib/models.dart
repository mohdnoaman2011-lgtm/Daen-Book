import 'dart:math' as math;
import 'package:intl/intl.dart';

const String kCurrency = 'ج.س';

final NumberFormat _numFmt = NumberFormat('#,##0.##', 'en');
String fmt(num n) => _numFmt.format(n);
String fmtDate(DateTime d) => DateFormat('dd/MM', 'en').format(d);

/// يقبل الأرقام العربية والهندية ويحوّلها إلى رقم.
double? parseNum(String s) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var out = s.trim();
  for (var i = 0; i < 10; i++) {
    out = out.replaceAll(arabic[i], '$i');
  }
  out = out.replaceAll('٫', '.').replaceAll('٬', '').replaceAll(',', '');
  return double.tryParse(out);
}

class Purchase {
  Purchase({
    required this.product,
    required this.price,
    required this.qty,
    required this.date,
  });

  final String product;
  final double price;
  final double qty;
  final DateTime date;

  double get total => price * qty;

  Map<String, dynamic> toJson() => {
        'product': product,
        'price': price,
        'qty': qty,
        'date': date.toIso8601String(),
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        product: j['product'] as String,
        price: (j['price'] as num).toDouble(),
        qty: (j['qty'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
      );
}

class Payment {
  Payment({required this.amount, required this.note, required this.date});

  final double amount;
  final String note;
  final DateTime date;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'note': note,
        'date': date.toIso8601String(),
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
      );
}

class Creditor {
  Creditor({
    required this.id,
    required this.name,
    List<Purchase>? purchases,
    List<Payment>? payments,
  })  : purchases = purchases ?? [],
        payments = payments ?? [];

  final int id;
  final String name;
  final List<Purchase> purchases;
  final List<Payment> payments;

  double get total => purchases.fold<double>(0, (a, p) => a + p.total);
  double get paid => payments.fold<double>(0, (a, p) => a + p.amount);
  double get remaining => math.max(0.0, total - paid);
  bool get settled => remaining <= 0;
  int get percent =>
      total > 0 ? (paid / total * 100).clamp(0, 100).round() : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'purchases': purchases.map((e) => e.toJson()).toList(),
        'payments': payments.map((e) => e.toJson()).toList(),
      };

  factory Creditor.fromJson(Map<String, dynamic> j) => Creditor(
        id: j['id'] as int,
        name: j['name'] as String,
        purchases: (j['purchases'] as List)
            .map((e) => Purchase.fromJson(e as Map<String, dynamic>))
            .toList(),
        payments: (j['payments'] as List)
            .map((e) => Payment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
