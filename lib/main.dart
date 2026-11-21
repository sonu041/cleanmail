import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/services/log_service.dart';
import 'core/theme/app_theme.dart';
import 'data/local/sample_data.dart';
import 'features/inbox/presentation/screens/inbox_screen.dart';
import 'features/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize operation logger
  await LogService().init();

  // Create a Riverpod container to initialize and seed local cache
  final container = ProviderContainer();

  try {
    final accountRepo = container.read(accountRepositoryProvider);
    final messageRepo = container.read(messageRepositoryProvider);
    final db = container.read(databaseProvider);
    await SampleDataSeeder.seedIfEmpty(
      accountRepo: accountRepo,
      messageRepo: messageRepo,
      db: db,
    );
  } catch (e) {
    debugPrint('Initial seeder note: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const CleanMailApp(),
    ),
  );
}

class CleanMailApp extends ConsumerWidget {
  const CleanMailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeChoice = ref.watch(themeModeProvider);

    // Resolve ThemeData and ThemeMode based on user selection
    final ThemeData effectiveLightTheme;
    final ThemeData effectiveDarkTheme;
    final ThemeMode effectiveThemeMode;

    switch (themeChoice) {
      case AppThemeMode.nerd:
        effectiveLightTheme = AppTheme.nerdTheme;
        effectiveDarkTheme = AppTheme.nerdTheme;
        effectiveThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.light:
        effectiveLightTheme = AppTheme.lightTheme;
        effectiveDarkTheme = AppTheme.darkTheme;
        effectiveThemeMode = ThemeMode.light;
        break;
      case AppThemeMode.dark:
        effectiveLightTheme = AppTheme.lightTheme;
        effectiveDarkTheme = AppTheme.darkTheme;
        effectiveThemeMode = ThemeMode.dark;
        break;
      case AppThemeMode.system:
        effectiveLightTheme = AppTheme.lightTheme;
        effectiveDarkTheme = AppTheme.darkTheme;
        effectiveThemeMode = ThemeMode.system;
        break;
    }

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: effectiveLightTheme,
      darkTheme: effectiveDarkTheme,
      themeMode: effectiveThemeMode,
      home: const InboxScreen(),
    );
  }
}
