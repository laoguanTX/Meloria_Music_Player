import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_taggy/flutter_taggy.dart';
import 'providers/music_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Taggy.initialize();
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    titleBarStyle: TitleBarStyle.hidden,
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => MusicProvider()),
      ],
      child: ThemeProviderWrapper(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            final musicProvider = context.read<MusicProvider>();
            musicProvider.setThemeProvider(themeProvider);
            return DynamicColorBuilder(
              builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                final lightColorScheme = themeProvider.lightColorScheme ??
                    lightDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: Colors.lightBlue,
                      brightness: Brightness.light,
                    );
                final darkColorScheme = themeProvider.darkColorScheme ??
                    darkDynamic ??
                    ColorScheme.fromSeed(
                      seedColor: Colors.lightBlue,
                      brightness: Brightness.dark,
                    );
                return MaterialApp(
                  title: 'Meloria Music Player',
                  theme: ThemeData(
                    colorScheme: lightColorScheme,
                    useMaterial3: true,
                    fontFamily: themeProvider.fontFamilyName,
                    visualDensity: VisualDensity.adaptivePlatformDensity,
                    appBarTheme: AppBarTheme(
                      centerTitle: true,
                      backgroundColor: lightColorScheme.surface,
                      surfaceTintColor: Colors.transparent,
                      systemOverlayStyle: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.dark,
                        statusBarBrightness: Brightness.light,
                        systemNavigationBarColor: lightColorScheme.surface,
                        systemNavigationBarIconBrightness: Brightness.dark,
                        systemNavigationBarDividerColor: Colors.transparent,
                      ),
                    ),
                  ),
                  darkTheme: ThemeData(
                    colorScheme: darkColorScheme,
                    useMaterial3: true,
                    fontFamily: themeProvider.fontFamilyName,
                    visualDensity: VisualDensity.adaptivePlatformDensity,
                    appBarTheme: AppBarTheme(
                      centerTitle: true,
                      elevation: 0,
                      backgroundColor: darkColorScheme.surface,
                      surfaceTintColor: Colors.transparent,
                      systemOverlayStyle: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        statusBarIconBrightness: Brightness.light,
                        statusBarBrightness: Brightness.dark,
                        systemNavigationBarColor: darkColorScheme.surface,
                        systemNavigationBarIconBrightness: Brightness.light,
                        systemNavigationBarDividerColor: Colors.transparent,
                      ),
                    ),
                  ),
                  themeMode: themeProvider.themeMode,
                  home: const HomeScreen(),
                  debugShowCheckedModeBanner: false,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class ThemeProviderWrapper extends StatefulWidget {
  final Widget child;
  const ThemeProviderWrapper({super.key, required this.child});

  @override // 重写 createState 方法
  State<ThemeProviderWrapper> createState() => _ThemeProviderWrapperState();
}

class _ThemeProviderWrapperState extends State<ThemeProviderWrapper> with TickerProviderStateMixin {
  late ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider(vsync: this);
  }

  @override
  void dispose() {
    _themeProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _themeProvider,
      child: widget.child,
    );
  }
}
