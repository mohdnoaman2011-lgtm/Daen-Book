import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';

/// ألوان التطبيق (فاتح / داكن).
class Pal {
  const Pal({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.debt,
    required this.debtInk,
    required this.dangerBg,
    required this.ok,
    required this.track,
  });

  final Color bg, surface, surface2, ink, muted, line;
  final Color accent, accentInk, debt, debtInk, dangerBg, ok, track;

  static const light = Pal(
    bg: Color(0xFFF4F2EC),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFEEEBE3),
    ink: Color(0xFF17211E),
    muted: Color(0xFF5C6863),
    line: Color(0xFFE0DCD0),
    accent: Color(0xFF0E6B5B),
    accentInk: Color(0xFFFFFFFF),
    debt: Color(0xFFB3402B),
    debtInk: Color(0xFFFFFFFF),
    dangerBg: Color(0xFFFBEFEB),
    ok: Color(0xFF1F7A4D),
    track: Color(0xFFE2DED2),
  );

  static const dark = Pal(
    bg: Color(0xFF101615),
    surface: Color(0xFF18211F),
    surface2: Color(0xFF212D2A),
    ink: Color(0xFFEAF0ED),
    muted: Color(0xFF9DAAA5),
    line: Color(0xFF2C3936),
    accent: Color(0xFF3FBFA5),
    accentInk: Color(0xFF07201B),
    debt: Color(0xFFFF9B85),
    debtInk: Color(0xFF2B0D06),
    dangerBg: Color(0xFF2A1B18),
    ok: Color(0xFF6FD3A0),
    track: Color(0xFF2C3936),
  );

  static Pal of(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark ? dark : light;
}

TextStyle ts(BuildContext c,
    {double size = 14, FontWeight weight = FontWeight.w400, Color? color, double? height}) {
  return GoogleFonts.cairo(
    fontSize: size,
    fontWeight: weight,
    color: color ?? Pal.of(c).ink,
    height: height,
  );
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  final base = ThemeData(brightness: b, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: p.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: p.accent, brightness: b).copyWith(
      primary: p.accent,
      onPrimary: p.accentInk,
      surface: p.surface,
      onSurface: p.ink,
    ),
    textTheme: GoogleFonts.cairoTextTheme(base.textTheme)
        .apply(bodyColor: p.ink, displayColor: p.ink),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.surface2,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => GoogleFonts.cairo(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
          )),
    ),
  );
}

void toast(BuildContext context, String msg, {String? actionLabel, VoidCallback? onAction}) {
  final p = Pal.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center, style: ts(context, size: 14, weight: FontWeight.w600, color: p.bg)),
      backgroundColor: p.ink,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(milliseconds: onAction == null ? 2400 : 6000),
      action: onAction == null
          ? null
          : SnackBarAction(label: actionLabel ?? 'تراجع', textColor: p.accent, onPressed: onAction),
    ));
}

// ---------------------------------------------------------------- widgets

class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, [this.subtitle]);
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: ts(context, size: 26, weight: FontWeight.w800)),
      if (subtitle != null)
        Text(subtitle!, style: ts(context, size: 14, color: p.muted)),
    ]);
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 18,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.line),
      ),
      child: child,
    );
  }
}

enum BtnKind { filled, outline, ink, danger, ghost, red }

class Btn extends StatelessWidget {
  const Btn(this.label, {super.key, required this.onPressed, this.kind = BtnKind.filled, this.icon, this.height = 52});
  final String label;
  final VoidCallback? onPressed;
  final BtnKind kind;
  final IconData? icon;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    Color bg, fg;
    BorderSide side = BorderSide.none;
    switch (kind) {
      case BtnKind.filled:
        bg = p.accent; fg = p.accentInk; break;
      case BtnKind.outline:
        bg = Colors.transparent; fg = p.accent; side = BorderSide(color: p.accent, width: 2); break;
      case BtnKind.ink:
        bg = p.ink; fg = p.bg; break;
      case BtnKind.danger:
        bg = p.debt; fg = p.debtInk; break;
      case BtnKind.ghost:
        bg = Colors.transparent; fg = p.ink; side = BorderSide(color: p.line, width: 2); break;
      case BtnKind.red:
        bg = const Color(0xFFD32F2F); fg = Colors.white; break;
    }
    final text = Text(label, style: ts(context, size: 15, weight: FontWeight.w700, color: fg));
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          disabledBackgroundColor: p.track,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: side),
        ),
        child: icon == null
            ? text
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: text)),
              ]),
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.number = false,
    this.optional = false,
  });
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool number;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c, width: w),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text.rich(TextSpan(children: [
        TextSpan(text: label, style: ts(context, size: 14, weight: FontWeight.w600)),
        if (optional)
          TextSpan(text: ' (اختياري)', style: ts(context, size: 14, color: p.muted)),
      ])),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: ts(context, size: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: ts(context, size: 16, color: p.muted),
          filled: true,
          fillColor: p.surface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          border: border(p.line),
          enabledBorder: border(p.line),
          focusedBorder: border(p.accent, 2),
        ),
      ),
    ]);
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar(this.percent, {super.key, this.height = 10});
  final int percent;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: p.track,
        alignment: AlignmentDirectional.centerStart,
        child: FractionallySizedBox(
          widthFactor: percent / 100,
          child: Container(color: p.ok),
        ),
      ),
    );
  }
}

class Money extends StatelessWidget {
  const Money(this.value, {super.key, this.size = 22, this.color, this.weight = FontWeight.w800});
  final double value;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final p = Pal.of(context);
    return Text.rich(TextSpan(children: [
      TextSpan(text: _f(value), style: ts(context, size: size, weight: weight, color: color)),
      TextSpan(text: ' $_cur', style: ts(context, size: size * 0.55, weight: FontWeight.w600, color: color ?? p.muted)),
    ]));
  }
}

String _f(double v) => fmt(v);
const String _cur = kCurrency;