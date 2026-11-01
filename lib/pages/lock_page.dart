import 'dart:async';
import 'package:flutter/material.dart';
import '../store.dart';
import '../ui.dart';

/// يغطي التطبيق بشاشة الرمز عند التشغيل وبعد البقاء خارج التطبيق دقيقة أو أكثر.
/// المحتوى يبقى مبنيًا تحت الشاشة حتى لا تضيع بيانات أي نموذج قيد الكتابة.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.store, required this.child});
  final DebtStore store;
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  DateTime? _leftAt;
  static const _lockAfter = Duration(seconds: 60);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final t = _leftAt;
      _leftAt = null;
      if (t != null && DateTime.now().difference(t) >= _lockAfter) {
        widget.store.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => Stack(children: [
        widget.child,
        if (widget.store.locked) Positioned.fill(child: LockScreen(store: widget.store)),
      ]),
    );
  }
}

/// شاشة إدخال الرمز (4 أرقام).
class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.store});
  final DebtStore store;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _entry = '';
  String? _error;
  int _fails = 0;
  int _wait = 0; // ثوانٍ متبقية للمحاولة التالية
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tap(String d) {
    if (_wait > 0 || _entry.length >= 4) return;
    setState(() {
      _entry += d;
      _error = null;
    });
    if (_entry.length == 4) _check();
  }

  void _back() {
    if (_wait > 0 || _entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  void _check() {
    if (widget.store.checkPin(_entry)) {
      widget.store.unlock();
      return;
    }
    _fails++;
    setState(() {
      _entry = '';
      _error = 'الرمز غير صحيح';
    });
    if (_fails >= 5) {
      _fails = 0;
      setState(() => _wait = 30);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _wait--);
        if (_wait <= 0) t.cancel();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: SizedBox(
              height: 64,
              child: TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  backgroundColor: onTap == null ? Colors.transparent : p.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: icon != null
                    ? Icon(icon, color: p.ink)
                    : Text(label, style: ts(context, size: 24, weight: FontWeight.w700)),
              ),
            ),
          ),
        );

    Widget row(List<String> ds) => Row(children: [for (final d in ds) key(d, onTap: () => _tap(d))]);

    return Material(
      color: p.bg,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.lock_outline, size: 44, color: p.accent),
                const SizedBox(height: 12),
                Text('دفتر الديون', style: ts(context, size: 22, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('أدخل الرمز للمتابعة', style: ts(context, size: 14, color: p.muted)),
                const SizedBox(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (var i = 0; i < 4; i++)
                    Container(
                      width: 16,
                      height: 16,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _entry.length ? p.accent : Colors.transparent,
                        border: Border.all(color: p.accent, width: 2),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  height: 22,
                  child: Text(
                    _wait > 0 ? 'محاولات كثيرة. انتظر $_wait ثانية' : (_error ?? ''),
                    style: ts(context, size: 13, weight: FontWeight.w700, color: p.debt),
                  ),
                ),
                const SizedBox(height: 10),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Column(children: [
                    row(['1', '2', '3']),
                    row(['4', '5', '6']),
                    row(['7', '8', '9']),
                    Row(children: [
                      key('', onTap: null),
                      key('0', onTap: () => _tap('0')),
                      key('', icon: Icons.backspace_outlined, onTap: _back),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- حوارات الإعداد

/// يطلب رمزًا جديدًا مرتين ثم يحفظه. يعيد true عند النجاح.
Future<bool> showPinSetupDialog(BuildContext context, DebtStore store) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(store: store, mode: _PinMode.setup),
  );
  return r ?? false;
}

/// يطلب الرمز الحالي. يعيد true إن كان صحيحًا.
Future<bool> showPinVerifyDialog(BuildContext context, DebtStore store) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => _PinDialog(store: store, mode: _PinMode.verify),
  );
  return r ?? false;
}

enum _PinMode { setup, verify }

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.store, required this.mode});
  final DebtStore store;
  final _PinMode mode;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  Future<void> _ok() async {
    final a = _a.text.trim();
    if (widget.mode == _PinMode.verify) {
      if (widget.store.checkPin(a)) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'الرمز غير صحيح');
      }
      return;
    }
    if (!RegExp(r'^\d{4}$').hasMatch(a)) {
      setState(() => _error = 'الرمز يجب أن يكون 4 أرقام');
      return;
    }
    if (a != _b.text.trim()) {
      setState(() => _error = 'الرمزان غير متطابقين');
      return;
    }
    await widget.store.setPin(a);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    final setup = widget.mode == _PinMode.setup;
    Widget field(String label, TextEditingController c) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: TextField(
            controller: c,
            obscureText: true,
            maxLength: 4,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: ts(context, size: 20, weight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: ts(context, size: 14, color: p.muted),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        );
    return AlertDialog(
      backgroundColor: p.surface,
      title: Text(setup ? 'تعيين رمز القفل' : 'أدخل الرمز الحالي',
          style: ts(context, size: 18, weight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (setup)
            Text('اختر رمزًا من 4 أرقام. إن نسيته فلن تستطيع فتح التطبيق إلا بمسح بياناته، فاحتفظ بنسخة احتياطية.',
                style: ts(context, size: 13, color: p.muted, height: 1.6)),
          field(setup ? 'الرمز الجديد' : 'الرمز', _a),
          if (setup) field('تأكيد الرمز', _b),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: ts(context, size: 13, weight: FontWeight.w700, color: p.debt)),
            ),
        ]),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('إلغاء', style: ts(context, size: 14, weight: FontWeight.w700, color: p.muted)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: p.accent, foregroundColor: p.accentInk),
          onPressed: _ok,
          child: Text('تأكيد', style: ts(context, size: 14, weight: FontWeight.w700, color: p.accentInk)),
        ),
      ],
    );
  }
}
