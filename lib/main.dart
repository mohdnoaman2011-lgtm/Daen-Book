import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'pages/add_page.dart';
import 'pages/home_page.dart';
import 'pages/more_page.dart';
import 'pages/splash_page.dart';
import 'pages/statement_page.dart';
import 'store.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // أي خطأ أثناء البناء يظهر نصه على الشاشة بدل شاشة فارغة.
  ErrorWidget.builder = (details) => Material(
        color: Colors.white,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                details.exceptionAsString(),
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ),
        ),
      );
  final store = DebtStore();
  try {
    await store.load().timeout(const Duration(seconds: 8));
  } catch (e, st) {
    runApp(_StartupError('$e\n\n$st'));
    return;
  }
  runApp(DebtApp(store: store));
}

/// تظهر عند فشل تحميل البيانات عند التشغيل، لمعرفة السبب.
class _StartupError extends StatelessWidget {
  const _StartupError(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: SelectableText(
                'خطأ عند بدء التطبيق:\n\n$message',
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DebtApp extends StatelessWidget {
  const DebtApp({super.key, required this.store});
  final DebtStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        title: 'دفتر الديون',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: store.themeMode,
        home: SplashPage(next: Shell(store: store)),
      ),
    );
  }
}

class Shell extends StatelessWidget {
  const Shell({super.key, required this.store});
  final DebtStore store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: IndexedStack(index: store.tab, children: [
            HomePage(store: store),
            AddPage(store: store),
            StatementPage(store: store),
            MorePage(store: store),
          ]),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: store.tab,
          onDestinationSelected: store.setTab,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), selectedIcon: Icon(Icons.shopping_bag), label: 'المشتريات'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'كشف الحساب'),
            NavigationDestination(icon: Icon(Icons.more_horiz), label: 'المزيد'),
          ],
        ),
      ),
    );
  }
}
