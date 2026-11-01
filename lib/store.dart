import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

/// حالة التطبيق + الحفظ المحلي على الهاتف (SharedPreferences).
class DebtStore extends ChangeNotifier {
  static const _kData = 'debt_data_v1';
  static const _kDark = 'debt_dark_mode';
  static const _kPin = 'debt_pin_v1';
  static const _kLastBackup = 'debt_last_backup';
  static const _kLastAuto = 'debt_last_auto_backup';

  late SharedPreferences _prefs;

  List<Creditor> creditors = [];
  ThemeMode themeMode = ThemeMode.light;
  int tab = 0;
  int? selectedId;

  // ---------- القفل ----------
  String? _pin; // "salt:hash"
  bool locked = false;

  // ---------- النسخ الاحتياطي ----------
  DateTime? lastBackup;
  bool backupSnoozed = false; // إخفاء التذكير حتى إغلاق التطبيق

  // ---------- للتراجع عن آخر حذف ----------
  VoidCallback? _undo;

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
    _pin = _prefs.getString(_kPin);
    locked = _pin != null;
    final lb = _prefs.getInt(_kLastBackup);
    lastBackup = lb == null ? null : DateTime.fromMillisecondsSinceEpoch(lb);
    selectedId = sorted.isNotEmpty ? sorted.first.id : null;
  }

  // ---------- قراءة ----------
  /// الدائنون النشطون (غير المؤرشفين).
  List<Creditor> get active => creditors.where((c) => !c.archived).toList();

  /// الدائنون المؤرشفون (الأحدث أولًا).
  List<Creditor> get archivedList =>
      creditors.where((c) => c.archived).toList().reversed.toList();

  List<Creditor> get sorted {
    final l = active;
    l.sort((a, b) => b.remaining.compareTo(a.remaining));
    return l;
  }

  double get totalDebt => active.fold<double>(0, (a, c) => a + c.total);
  double get totalPaid => active.fold<double>(0, (a, c) => a + c.paid);
  double get totalRemaining =>
      active.fold<double>(0, (a, c) => a + c.remaining);
  int get overallPercent => totalDebt > 0
      ? (totalPaid / totalDebt * 100).clamp(0, 100).round()
      : 0;

  /// عدد الدائنين الذين ما زال عليهم متبقٍ.
  int get owingCount => active.where((c) => !c.settled).length;

  Creditor? get selected {
    for (final c in creditors) {
      if (c.id == selectedId) return c;
    }
    final a = sorted;
    return a.isEmpty ? null : a.first;
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
      final found = creditors.firstWhere((c) => c.id == creditorId);
      if (found.archived) {
        // الدائن المؤرشف لا تُضاف إليه ديون جديدة: نُنشئ سجلًا جديدًا منفصلًا بنفس الاسم.
        final nextId = creditors.fold<int>(0, (m, c) => math.max(m, c.id)) + 1;
        target = Creditor(id: nextId, name: found.name);
        creditors.add(target);
      } else {
        target = found;
      }
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
  double addPayment(Creditor c, double amount, String note,
      {String method = '', DateTime? date}) {
    final amt = math.min(amount, c.remaining);
    if (amt <= 0) return 0;
    c.payments.add(Payment(
      amount: amt,
      note: note.trim(),
      method: method,
      date: date ?? DateTime.now(),
    ));
    _commit();
    return amt;
  }

  // ---------- تعديل وحذف العمليات ----------
  void editPurchase(Creditor c, int i, Purchase np) {
    if (i < 0 || i >= c.purchases.length) return;
    c.purchases[i] = np;
    _commit();
  }

  void deletePurchase(Creditor c, int i) {
    if (i < 0 || i >= c.purchases.length) return;
    final item = c.purchases.removeAt(i);
    _undo = () {
      c.purchases.insert(math.min(i, c.purchases.length), item);
      _commit();
    };
    _commit();
  }

  void editPayment(Creditor c, int i, Payment np) {
    if (i < 0 || i >= c.payments.length) return;
    c.payments[i] = np;
    _commit();
  }

  void deletePayment(Creditor c, int i) {
    if (i < 0 || i >= c.payments.length) return;
    final item = c.payments.removeAt(i);
    _undo = () {
      c.payments.insert(math.min(i, c.payments.length), item);
      _commit();
    };
    _commit();
  }

  /// يتراجع عن آخر حذف لعملية أو دفعة.
  void undoLast() {
    final u = _undo;
    _undo = null;
    u?.call();
  }

  // ---------- الأرشفة ----------
  /// ينقل الدائن (المسدّد) إلى الأرشيف مع بقاء بياناته القديمة.
  void archiveCreditor(Creditor c) {
    c.archived = true;
    final a = sorted;
    selectedId = a.isEmpty ? null : a.first.id;
    _undo = () {
      c.archived = false;
      selectedId = c.id;
      _commit();
    };
    _commit();
  }

  Creditor? _lastRemoved;

  /// يحذف الدائن وكل سجلاته من جميع الأماكن (قائمة واحدة).
  void removeCreditor(int id) {
    final i = creditors.indexWhere((c) => c.id == id);
    if (i < 0) return;
    _lastRemoved = creditors.removeAt(i);
    selectedId = sorted.isNotEmpty ? sorted.first.id : null;
    _commit();
  }

  /// يتراجع عن آخر حذف.
  void undoRemove() {
    final c = _lastRemoved;
    if (c == null) return;
    creditors.add(c);
    selectedId = c.id;
    _lastRemoved = null;
    _commit();
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

  // ---------- قفل التطبيق (رمز من 4 أرقام) ----------
  bool get pinEnabled => _pin != null;

  static String _hash(String salt, String pin) {
    var h = 17;
    for (var r = 0; r < 2000; r++) {
      for (final u in '$salt|$pin|$r'.codeUnits) {
        h = (h * 31 + u) & 0x3FFFFFFFFFFFFFFF;
      }
    }
    return h.toRadixString(16);
  }

  Future<void> setPin(String pin) async {
    final salt = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    _pin = '$salt:${_hash(salt, pin)}';
    await _prefs.setString(_kPin, _pin!);
    locked = false;
    notifyListeners();
  }

  bool checkPin(String pin) {
    final p = _pin;
    if (p == null) return true;
    final i = p.indexOf(':');
    if (i < 0) return false;
    return p.substring(i + 1) == _hash(p.substring(0, i), pin);
  }

  Future<void> clearPin() async {
    _pin = null;
    await _prefs.remove(_kPin);
    locked = false;
    notifyListeners();
  }

  void lock() {
    if (_pin != null && !locked) {
      locked = true;
      notifyListeners();
    }
  }

  void unlock() {
    locked = false;
    notifyListeners();
  }

  // ---------- تذكير وحفظ النسخ ----------
  /// هل مضى أكثر من أسبوع على آخر نسخة احتياطية (أو لم تُؤخذ أبدًا)؟
  bool get backupDue {
    if (creditors.isEmpty || backupSnoozed) return false;
    final lb = lastBackup;
    return lb == null || DateTime.now().difference(lb).inDays >= 7;
  }

  /// عدد الأيام منذ آخر نسخة (null إن لم تُؤخذ).
  int? get daysSinceBackup =>
      lastBackup == null ? null : DateTime.now().difference(lastBackup!).inDays;

  Future<void> markBackup() async {
    lastBackup = DateTime.now();
    await _prefs.setInt(_kLastBackup, lastBackup!.millisecondsSinceEpoch);
    notifyListeners();
  }

  void snoozeBackup() {
    backupSnoozed = true;
    notifyListeners();
  }

  // ---------- نسخة تلقائية أسبوعية داخل التطبيق ----------
  Future<Directory> _autoDir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory('${base.path}/auto_backups');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// النسخ التلقائية المحفوظة (الأحدث أولًا).
  Future<List<File>> listAutoBackups() async {
    final d = await _autoDir();
    final l = d
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    l.sort((a, b) => b.path.compareTo(a.path));
    return l;
  }

  /// يحفظ نسخة تلقائية إن مضى أسبوع على آخر واحدة، ويُبقي آخر 5 نسخ.
  Future<void> autoBackupIfDue() async {
    try {
      if (creditors.isEmpty) return;
      final last = _prefs.getInt(_kLastAuto);
      final now = DateTime.now();
      if (last != null &&
          now.difference(DateTime.fromMillisecondsSinceEpoch(last)).inDays < 7) {
        return;
      }
      final d = await _autoDir();
      final f = File('${d.path}/auto_${now.toIso8601String().substring(0, 10)}.json');
      await f.writeAsString(exportJson(), flush: true);
      await _prefs.setInt(_kLastAuto, now.millisecondsSinceEpoch);
      final all = await listAutoBackups();
      for (final x in all.skip(5)) {
        await x.delete();
      }
    } catch (_) {}
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
    selectedId = sorted.isNotEmpty ? sorted.first.id : null;
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
