import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:window_manager/window_manager.dart'; // 新增导入
import 'package:flutter_taggy/flutter_taggy.dart'; // Added for flutter_taggy
import 'providers/music_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  // 修改为 async
  WidgetsFlutterBinding.ensureInitialized();
  Taggy.initialize(); // Added for flutter_taggy

  // 初始化 window_manager
  await windowManager.ensureInitialized();

  // 设置窗口标题栏样式为隐藏
  WindowOptions windowOptions = const WindowOptions(
    titleBarStyle: TitleBarStyle.hidden, // 确保取消注释或设置为 hidden
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 恢复默认的系统UI模式
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 恢复默认的系统UI样式
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      // statusBarColor: Colors.transparent, // 根据主题自动调整
      // systemNavigationBarColor: Colors.transparent, // 根据主题自动调整
      // systemNavigationBarDividerColor: Colors.transparent, // 根据主题自动调整
      ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 需要 TickerProviderStateMixin，所以不能直接在这里创建
        // ChangeNotifierProvider(create: (context) => ThemeProvider()),
        ChangeNotifierProvider(create: (context) => MusicProvider()),
      ],
      // child: Consumer<ThemeProvider>( // 旧的 Consumer
      // 为了 ThemeProvider 的 TickerProvider，我们需要一个 StatefulWidget
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

                // Define a base text theme
                final baseTextTheme = Typography.dense2021
                    .copyWith(
                      bodyLarge: const TextStyle(fontWeight: FontWeight.bold),
                      bodyMedium: const TextStyle(fontWeight: FontWeight.bold),
                      bodySmall: const TextStyle(fontWeight: FontWeight.bold),
                      displayLarge:
                          const TextStyle(fontWeight: FontWeight.bold),
                      displayMedium:
                          const TextStyle(fontWeight: FontWeight.bold),
                      displaySmall:
                          const TextStyle(fontWeight: FontWeight.bold),
                      headlineLarge:
                          const TextStyle(fontWeight: FontWeight.bold),
                      headlineMedium:
                          const TextStyle(fontWeight: FontWeight.bold),
                      headlineSmall:
                          const TextStyle(fontWeight: FontWeight.bold),
                      labelLarge: const TextStyle(fontWeight: FontWeight.bold),
                      labelMedium: const TextStyle(fontWeight: FontWeight.bold),
                      labelSmall: const TextStyle(fontWeight: FontWeight.bold),
                      titleLarge: const TextStyle(fontWeight: FontWeight.bold),
                      titleMedium: const TextStyle(fontWeight: FontWeight.bold),
                      titleSmall: const TextStyle(fontWeight: FontWeight.bold),
                    )
                    .apply(
                        fontFamily:
                            'MiSans-Bold'); // Apply the font family once

                return MaterialApp(
                  title: 'Music Player',
                  theme: ThemeData(
                    colorScheme: lightColorScheme,
                    useMaterial3: true,
                    fontFamily: 'MiSans-Bold', // Set global font family
                    textTheme: baseTextTheme, // Use the optimized text theme
                    visualDensity: VisualDensity.adaptivePlatformDensity,
                    appBarTheme: AppBarTheme(
                      centerTitle: true,
                      elevation: 0,
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
                    fontFamily: 'MiSans-Bold', // Set global font family
                    textTheme: baseTextTheme, // Use the optimized text theme
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
                  themeMode: themeProvider.themeMode, // 修改为从 ThemeProvider 获取
                  home: const HomeScreen(), // 移除SafeArea以实现真正全屏
                  debugShowCheckedModeBanner: false, // 确保调试横幅已移除
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// 新增 StatefulWidget 来提供 TickerProvider
class ThemeProviderWrapper extends StatefulWidget {
  final Widget child;
  const ThemeProviderWrapper({super.key, required this.child});

  @override
  State<ThemeProviderWrapper> createState() => _ThemeProviderWrapperState();
}

class _ThemeProviderWrapperState extends State<ThemeProviderWrapper>
    with TickerProviderStateMixin {
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
