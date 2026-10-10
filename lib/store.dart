import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// حالة التطبيق + الحفظ المحلي على الهاتف (SharedPreferences).
class DebtStore extends ChangeNotifier {
  static const _kData = 'debt_data_v1';
  static const _kDark = 'debt_dark_mode';

  late SharedPreferences _prefs;

  List<Creditor> creditors = [];
  ThemeMode themeMode = ThemeMode.light;
  int tab = 0;
  int? selectedId;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_kData);
    if (raw != null) {
      try {
        _decode(raw);
      } catch (_) {
        creditors = [];
      }
    }
    themeMode =
        (_prefs.getBool(_kDark) ?? false) ? ThemeMode.dark : ThemeMode.light;
    selectedId = creditors.isNotEmpty ? sorted.first.id : null;
  }

  // ---------- قراءة ----------
  List<Creditor> get sorted {
    final l = [...creditors];
    l.sort((a, b) => b.remaining.compareTo(a.remaining));
    return l;
  }

  double get totalDebt => creditors.fold<double>(0, (a, c) => a + c.total);
  double get totalPaid => creditors.fold<double>(0, (a, c) => a + c.paid);
  double get totalRemaining =>
      creditors.fold<double>(0, (a, c) => a + c.remaining);
  int get overallPercent => totalDebt > 0
      ? (totalPaid / totalDebt * 100).clamp(0, 100).round()
      : 0;

  Creditor? get selected {
    if (creditors.isEmpty) return null;
    for (final c in creditors) {
      if (c.id == selectedId) return c;
    }
    return creditors.first;
  }

  // ---------- تنقل ----------
  void setTab(int i) {
    tab = i;
    notifyListeners();
  }

  void openStatement(int creditorId) {
    selectedId = creditorId;
    tab = 2;
    notifyListeners();
  }

  void select(int id) {
    selectedId = id;
    notifyListeners();
  }

  // ---------- عمليات ----------
  /// يضيف عملية شراء. إن كان [newName] غير فارغ يُنشأ دائن جديد.
  /// يعيد اسم الدائن.
  String addPurchase({
    int? creditorId,
    String? newName,
    required String product,
    required double price,
    required double qty,
    DateTime? date,
  }) {
    Creditor target;
    if (newName != null && newName.trim().isNotEmpty) {
      final nextId = creditors.fold<int>(0, (m, c) => math.max(m, c.id)) + 1;
      target = Creditor(id: nextId, name: newName.trim());
      creditors.add(target);
    } else {
      target = creditors.firstWhere((c) => c.id == creditorId);
    }
    target.purchases.add(Purchase(
      product: product.trim(),
      price: price,
      qty: qty,
      date: date ?? DateTime.now(),
    ));
    selectedId = target.id;
    _commit();
    return target.name;
  }

  /// يسجل دفعة (لا تتجاوز المتبقي). يعيد المبلغ المسجل فعليًا.
  double addPayment(Creditor c, double amount, String note) {
    final amt = math.min(amount, c.remaining);
    if (amt <= 0) return 0;
    c.payments.add(Payment(amount: amt, note: note.trim(), date: DateTime.now()));
    _commit();
    return amt;
  }

  void clearAll() {
    creditors = [];
    selectedId = null;
    _commit();
  }

  Future<void> setDark(bool dark) async {
    themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setBool(_kDark, dark);
    notifyListeners();
  }

  // ---------- نسخ احتياطي ----------
  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'app': 'debt_book',
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'creditors': creditors.map((c) => c.toJson()).toList(),
      });

  /// يرمي FormatException إن كان الملف غير صالح.
  void importJson(String raw) {
    final test = jsonDecode(raw);
    if (test is! Map<String, dynamic> || test['app'] != 'debt_book') {
      throw const FormatException('ملف غير صالح');
    }
    _decode(raw);
    selectedId = creditors.isNotEmpty ? sorted.first.id : null;
    _commit();
  }

  void _decode(String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    creditors = (m['creditors'] as List)
        .map((e) => Creditor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _commit() {
    _prefs.setString(_kData, exportJson());
    notifyListeners();
  }
}
