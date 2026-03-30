import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'config/supabase_config.dart';
import 'constants.dart';
import 'database/database_helper.dart';
import 'database/sync_queue_helper.dart';
import 'database/supabase_repository.dart';
import 'providers/auth_provider.dart';
import 'providers/household_provider.dart';
import 'providers/bill_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/recurring_bill_provider.dart';
import 'screens/household_screen.dart';
import 'screens/home_screen.dart';
import 'screens/launch_screen.dart';
import 'screens/bill_type_screen.dart';
import 'screens/camera_screen.dart';
import 'screens/item_review_screen.dart';
import 'screens/quick_review_screen.dart';
import 'screens/bill_detail_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/recurring_bills_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/invite_screen.dart';
import 'screens/join_household_screen.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/notification_service.dart';
import 'services/settlement_service.dart';
import 'services/invite_service.dart';
import 'services/push_notification_service.dart';
import 'services/sync_service.dart';
import 'screens/notifications_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final screenWidth = view.physicalSize.width / view.devicePixelRatio;
  AppScale.init(screenWidth);
  await Firebase.initializeApp();

  // Crashlytics: catch all Flutter framework errors
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  // Crashlytics: catch async errors not handled by Flutter
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  final connectivityService = ConnectivityService();
  await connectivityService.init();

  final syncQueueHelper = SyncQueueHelper(DatabaseHelper.instance);
  DatabaseHelper.instance.setSyncQueue(syncQueueHelper);

  final supabaseRepo = SupabaseRepository(Supabase.instance.client);
  final authService = AuthService(Supabase.instance.client);
  final syncService = SyncService(
    DatabaseHelper.instance,
    supabaseRepo,
    syncQueueHelper,
    connectivityService,
  );

  final settlementService = SettlementService(Supabase.instance.client);
  final notificationService = NotificationService(Supabase.instance.client);
  final inviteService = InviteService(Supabase.instance.client);
  final pushService = PushNotificationService(Supabase.instance.client);

  if (Supabase.instance.client.auth.currentUser != null) {
    try {
      await pushService.init();
    } catch (e) {
      debugPrint('Push init error: $e');
    }
    notificationService.loadNotifications();
    notificationService.subscribeToRealtime();
  }

  final settingsProvider = SettingsProvider();
  await settingsProvider.loadSettings();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HouseholdProvider()),
        ChangeNotifierProvider(create: (_) => BillProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider(create: (_) => RecurringBillProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider(authService)),
        Provider.value(value: connectivityService),
        ChangeNotifierProvider.value(value: notificationService),
        ChangeNotifierProvider.value(value: syncService),
        Provider.value(value: supabaseRepo),
        Provider.value(value: settlementService),
        Provider.value(value: inviteService),
        Provider.value(value: pushService),
      ],
      child: const BillSplitApp(),
    ),
  );
}

class BillSplitApp extends StatefulWidget {
  const BillSplitApp({super.key});

  @override
  State<BillSplitApp> createState() => _BillSplitAppState();
}

class _BillSplitAppState extends State<BillSplitApp> with WidgetsBindingObserver {
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
    final notificationService = context.read<NotificationService>();

    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground — refresh data and reconnect
        notificationService.loadNotifications();
        notificationService.subscribeToRealtime();
        break;
      case AppLifecycleState.paused:
        // App went to background — unsubscribe realtime to save battery
        notificationService.unsubscribe();
        break;
      default:
        break;
    }
  }

  static TextTheme _buildTextTheme(TextTheme base) {
    return GoogleFonts.lexendTextTheme(base);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<SettingsProvider>().themeMode;

    // ── Light Color Scheme ──
    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      tertiary: AppColors.accent,
      error: AppColors.negative,
      surface: AppColors.surface,
    );

    // ── Dark Color Scheme ──
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: AppColors.primaryLight,
      tertiary: AppColors.accent,
      error: AppColors.negative,
      surface: AppColors.darkSurface,
    );

    return MaterialApp(
      title: 'FairShare',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,

      // ════════════════════════════════════════════════════════
      //  LIGHT THEME — Flat Design Mobile (Touch-First)
      // ════════════════════════════════════════════════════════
      theme: ThemeData(
        colorScheme: lightColorScheme,
        useMaterial3: true,
        brightness: Brightness.light,
        textTheme: _buildTextTheme(ThemeData.light().textTheme),
        scaffoldBackgroundColor: AppColors.background,

        // AppBar — clean, flat
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
          titleTextStyle: GoogleFonts.lexend(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          iconTheme: const IconThemeData(color: AppColors.textPrimary),
        ),

        // Cards — flat, no border, no shadow
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          margin: EdgeInsets.zero,
        ),

        // Filled Buttons — bold, flat
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Outlined Buttons — clean border
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            side: const BorderSide(color: AppColors.divider, width: 1.5),
            textStyle: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Text Buttons
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Input fields — subtle, clean
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: const BorderSide(color: AppColors.negative, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        // Chips
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          side: BorderSide.none,
        ),

        // Dividers
        dividerTheme: const DividerThemeData(
          color: AppColors.divider,
          thickness: 1,
          space: 1,
        ),

        // Snackbar
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),

        // FAB — flat, bold
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),

        // Dialog
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          elevation: 0,
        ),

        // Bottom Sheet
        bottomSheetTheme: const BottomSheetThemeData(
          elevation: 0,
          showDragHandle: false,
        ),

        // Page transitions
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      // ════════════════════════════════════════════════════════
      //  DARK THEME
      // ════════════════════════════════════════════════════════
      darkTheme: ThemeData(
        colorScheme: darkColorScheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        textTheme: _buildTextTheme(ThemeData.dark().textTheme),
        scaffoldBackgroundColor: AppColors.darkBackground,

        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.darkSurface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          titleTextStyle: GoogleFonts.lexend(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.darkTextPrimary,
          ),
        ),

        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.darkSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          margin: EdgeInsets.zero,
        ),

        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 52),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            textStyle: GoogleFonts.lexend(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            textStyle: GoogleFonts.lexend(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.darkSurfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide:
                const BorderSide(color: AppColors.primaryLight, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),

        dividerTheme: const DividerThemeData(
          color: AppColors.darkDivider,
          thickness: 1,
          space: 1,
        ),

        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),

        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: AppColors.darkBackground,
          elevation: 0,
          hoverElevation: 0,
          focusElevation: 0,
          highlightElevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),

        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          elevation: 0,
        ),

        bottomSheetTheme: const BottomSheetThemeData(
          elevation: 0,
          showDragHandle: false,
        ),

        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),

      home: const LaunchScreen(),
      routes: {
        '/households': (context) => const HouseholdScreen(),
        '/home': (context) => const HomeScreen(),
        '/bill-type': (context) => const BillTypeScreen(),
        '/camera': (context) => const CameraScreen(),
        '/item-review': (context) => const ItemReviewScreen(),
        '/quick-review': (context) => const QuickReviewScreen(),
        '/bill-detail': (context) => const BillDetailScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/recurring-bills': (context) => const RecurringBillsScreen(),
        '/auth': (context) => const AuthScreen(),
        '/notifications': (context) => const NotificationsScreen(),
        '/invite': (context) => const InviteScreen(),
        '/join-household': (context) => const JoinHouseholdScreen(),
      },
    );
  }
}
