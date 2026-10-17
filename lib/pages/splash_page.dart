import 'package:flutter/material.dart';
import '../ui.dart';

/// شاشة البداية: يظهر الشعار بحركة تدرّج وتكبير خفيف ثم تنتقل إلى التطبيق.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.next});

  /// الشاشة التي تُعرض بعد انتهاء شاشة البداية.
  final Widget next;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFFFFFFFF);
  static const _navy = Color(0xFF123A5E);
  static const _gold = Color(0xFFC9A24B);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
  late final Animation<double> _logoScale = Tween<double>(begin: 0.82, end: 1.0)
      .animate(CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack)));
  late final Animation<double> _textFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.55, 1.0, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2400), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (_, __, ___) => widget.next,
      transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            const Spacer(flex: 5),
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Image.asset('assets/images/logo.png', width: w * 0.62),
              ),
            ),
            const SizedBox(height: 18),
            FadeTransition(
              opacity: _textFade,
              child: Column(children: [
                Container(width: 44, height: 3, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 14),
                Text('سجّل ديونك وتابع سدادها بسهولة',
                    style: ts(context, size: 15, weight: FontWeight.w600, color: _navy.withOpacity(0.75))),
              ]),
            ),
            const Spacer(flex: 4),
            FadeTransition(
              opacity: _textFade,
              child: const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, color: _gold),
              ),
            ),
            const SizedBox(height: 40),
          ],
          ),
        ),
      ),
    );
  }
}
