import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/app_theme.dart';
import 'data/local/sample_data.dart';
import 'features/inbox/presentation/screens/inbox_screen.dart';
import 'features/providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Create a Riverpod container to initialize and seed local cache
  final container = ProviderContainer();

  try {
    final accountRepo = container.read(accountRepositoryProvider);
    final messageRepo = container.read(messageRepositoryProvider);
    await SampleDataSeeder.seedIfEmpty(
      accountRepo: accountRepo,
      messageRepo: messageRepo,
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

class CleanMailApp extends StatelessWidget {
  const CleanMailApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const InboxScreen(),
    );
  }
}
