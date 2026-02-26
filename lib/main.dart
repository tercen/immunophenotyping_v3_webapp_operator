import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sci_tercen_client/sci_client_service_factory.dart';
import 'package:sci_tercen_client/sci_service_factory_web.dart';

import 'core/theme/app_theme.dart';
import 'di/service_locator.dart';
import 'presentation/providers/app_state_provider.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (FlutterErrorDetails details) {
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

  const useMocks = bool.fromEnvironment('USE_MOCKS', defaultValue: false);

  ServiceFactory? factory;
  String? projectId;

  if (!useMocks) {
    try {
      // projectId is optional — Stage 0 creates the project.
      projectId = Uri.base.queryParameters['projectId'];
      if (projectId != null && projectId.isEmpty) projectId = null;
      factory = await createServiceFactoryForWebApp();
    } catch (e) {
      print('Tercen init failed: $e');
    }
  }

  try {
    setupServiceLocator(
      useMocks: factory == null,
      factory: factory,
      projectId: projectId,
    );
    final prefs = await SharedPreferences.getInstance();
    runApp(ImmunophenotypingApp(prefs: prefs));
  } catch (e, stack) {
    print('STARTUP ERROR: $e\n$stack');
    runApp(_buildErrorApp('STARTUP ERROR:\n$e\n\n$stack'));
  }
}

Widget _buildErrorApp(String message) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SelectableText(
            message,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ),
      ),
    ),
  );
}

class ImmunophenotypingApp extends StatelessWidget {
  final SharedPreferences prefs;

  const ImmunophenotypingApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(prefs)),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
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
