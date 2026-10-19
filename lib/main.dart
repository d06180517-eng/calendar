import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/app_state.dart';
import 'services/reminder_service.dart';
import 'services/weather_service.dart';
import 'ui/screens/auth_screen.dart';
import 'ui/screens/home_shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  await initializeDateFormatting('en');
  final state = AppState();
  await state.loadSettings();
  final reminders = ReminderService();
  await reminders.init();
  runApp(
    CalendarApp(state: state, reminders: reminders, weather: WeatherService()),
  );
}

class CalendarApp extends StatelessWidget {
  const CalendarApp({
    super.key,
    required this.state,
    required this.reminders,
    required this.weather,
  });

  final AppState state;
  final ReminderService reminders;
  final WeatherService weather;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: state),
        Provider.value(value: reminders),
        Provider.value(value: weather),
      ],
      child: Consumer<AppState>(
        builder: (context, s, _) => MaterialApp(
          title: 'Calendar',
          debugShowCheckedModeBanner: false,
          // В браузере ленту и календарь можно листать и мышью.
          scrollBehavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: s.themeMode,
          locale: s.languageCode == null ? null : Locale(s.languageCode!),
          supportedLocales: const [Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: s.isLoggedIn ? const HomeShell() : const AuthScreen(),
        ),
      ),
    );
  }
}
