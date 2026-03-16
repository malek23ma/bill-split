import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/household_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/household_screen.dart';
import 'screens/member_select_screen.dart';
import 'screens/home_screen.dart';
import 'screens/bill_type_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/item_review_screen.dart';
import 'screens/quick_review_screen.dart';
import 'screens/bill_detail_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HouseholdProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
      ],
      child: const BillSplitApp(),
    ),
  );
}

class BillSplitApp extends StatelessWidget {
  const BillSplitApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;

    return MaterialApp(
      title: 'Bill Split',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        brightness: Brightness.light,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        brightness: Brightness.dark,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HouseholdScreen(),
        '/select-member': (context) => const MemberSelectScreen(),
        '/home': (context) => const HomeScreen(),
        '/bill-type': (context) => const BillTypeScreen(),
        '/camera': (context) => const CameraScreen(),
        '/item-review': (context) => const ItemReviewScreen(),
        '/quick-review': (context) => const QuickReviewScreen(),
        '/bill-detail': (context) => const BillDetailScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
