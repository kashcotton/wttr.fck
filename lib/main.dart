import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content/content.dart';
import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Google Sans Flex'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  final content = await ContentRepo.bundled();
  final state = AppState(prefs, content);
  runApp(WttrApp(state: state));
  state.refresh(silent: true);
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

class WttrApp extends StatelessWidget {
  const WttrApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final seed = seedFor(state.forecast);
          return MaterialApp(
            title: 'wttr.fck',
            debugShowCheckedModeBanner: false,
            themeMode: state.themeMode,
            theme: buildTheme(seed, Brightness.light),
            darkTheme: buildTheme(seed, Brightness.dark),
            themeAnimationDuration: const Duration(milliseconds: 600),
            themeAnimationCurve: Curves.easeOutCubic,
            // Respect the user's text size, within reason, so layouts hold.
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(maxScaleFactor: 1.6),
                ),
                child: child!,
              );
            },
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
