import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'presentation/providers/app_state_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Show errors visually instead of blank screen
  ErrorWidget.builder = (FlutterErrorDetails details) {
    debugPrint('ErrorWidget: ${details.exception}');
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'ERROR:\n${details.exception}',
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
      ),
    );
  };

  debugPrint('[main] Starting app...');

  try {
    debugPrint('[main] Setting up service locator...');
    setupServiceLocator(useMocks: true);
    debugPrint('[main] Service locator ready');

    debugPrint('[main] Getting SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    debugPrint('[main] SharedPreferences ready');

    debugPrint('[main] Calling runApp...');
    runApp(ImmunophenotypingApp(prefs: prefs));
    debugPrint('[main] runApp called');
  } catch (e, stack) {
    debugPrint('[main] STARTUP ERROR: $e\n$stack');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SelectableText(
              'STARTUP ERROR:\n$e\n\n$stack',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ),
    ));
  }
}

class ImmunophenotypingApp extends StatelessWidget {
  final SharedPreferences prefs;

  const ImmunophenotypingApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    debugPrint('[ImmunophenotypingApp] build called');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          debugPrint('[ImmunophenotypingApp] Creating ThemeProvider');
          return ThemeProvider(prefs);
        }),
        ChangeNotifierProvider(create: (_) {
          debugPrint('[ImmunophenotypingApp] Creating AppStateProvider');
          return AppStateProvider();
        }),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          debugPrint('[ImmunophenotypingApp] Consumer rebuild');
          return MaterialApp(
            title: 'Flow Immunophenotyping - PhenoGraph',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            debugShowCheckedModeBanner: false,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
