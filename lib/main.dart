import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:window_manager/window_manager.dart'; // 新增导入
import 'providers/music_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/home_screen.dart';

void main() async {
  // 修改为 async
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 window_manager
  await windowManager.ensureInitialized();

  // 注册窗口监听器
  final MyWindowListener myWindowListener = MyWindowListener();
  windowManager.addListener(myWindowListener);

  // 设置窗口标题栏样式为隐藏
  WindowOptions windowOptions = const WindowOptions(
    titleBarStyle: TitleBarStyle.hidden, // 隐藏标题栏
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  // 设置全屏显示，完全隐藏系统UI（包括状态栏和导航栏）
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  // 设置系统UI样式为透明
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(const MyApp());
}

// 新增 WindowListener 实现
class MyWindowListener extends WindowListener {
  @override
  void onWindowMaximize() {
    super.onWindowMaximize();
    print('Window minimized!');
  }

  // 你可以根据需要覆盖其他窗口事件
  // 例如: onWindowClose, onWindowFocus, onWindowBlur, onWindowMaximize, onWindowUnmaximize, onWindowResize, onWindowMove
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

                return MaterialApp(
                  title: 'Music Player',
                  theme: ThemeData(
                    colorScheme: lightColorScheme,
                    useMaterial3: true,
                    fontFamily: 'Microsoft YaHei', // 推荐全局中文字体
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
                    fontFamily: 'NotoSansSC',
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
                  themeMode: ThemeMode.system,
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
