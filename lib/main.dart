import 'package:flutter/material.dart'; // 导入 Flutter 材料设计库
import 'package:flutter/services.dart'; // 导入 Flutter 服务库，用于系统级操作
import 'package:provider/provider.dart'; // 导入 Provider 状态管理库
import 'package:dynamic_color/dynamic_color.dart'; // 导入 dynamic_color 库，用于根据系统主题动态调整颜色
import 'package:window_manager/window_manager.dart'; // 导入 window_manager 库，用于管理窗口属性
import 'package:flutter_taggy/flutter_taggy.dart'; // 导入 flutter_taggy 库，用于读取音频标签
import 'providers/music_provider.dart'; // 导入音乐数据提供者
import 'providers/theme_provider.dart'; // 导入主题数据提供者
import 'screens/home_screen.dart'; // 导入主屏幕

void main() async {
  // 应用主入口函数，声明为异步
  WidgetsFlutterBinding.ensureInitialized(); // 确保 Flutter 绑定已初始化
  Taggy.initialize(); // 初始化 flutter_taggy 库

  await windowManager.ensureInitialized(); // 异步确保 window_manager 已初始化

  WindowOptions windowOptions = const WindowOptions(
    // 定义窗口选项
    titleBarStyle: TitleBarStyle.hidden, // 设置标题栏样式为隐藏
  );
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 等待窗口准备好显示
    await windowManager.show(); // 异步显示窗口
    await windowManager.focus(); // 异步聚焦窗口
  });

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge); // 设置系统 UI 模式为沉浸式边到边

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle()); // 设置系统 UI 覆盖层样式 (状态栏、导航栏颜色等)

  runApp(const MyApp()); // 运行应用
}

class MyApp extends StatelessWidget {
  // 应用主 Widget
  const MyApp({super.key}); // 构造函数
  @override // 重写 build 方法
  Widget build(BuildContext context) {
    // 构建 Widget 树
    return MultiProvider(
      // 使用 MultiProvider 来提供多个状态
      providers: [
        // 提供者列表
        ChangeNotifierProvider(create: (context) => MusicProvider()), // 创建并提供 MusicProvider
      ],
      child: ThemeProviderWrapper(
        // 使用 ThemeProviderWrapper 来包裹并提供 ThemeProvider
        child: Consumer<ThemeProvider>(
          // 消费 ThemeProvider
          builder: (context, themeProvider, child) {
            // 构建器函数AnimatedSwitcher
            final musicProvider = context.read<MusicProvider>(); // 读取 MusicProvider
            musicProvider.setThemeProvider(themeProvider); // 将 ThemeProvider 设置给 MusicProvider

            return DynamicColorBuilder(
              // 使用 DynamicColorBuilder 来根据系统主题动态构建颜色
              builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
                // 构建器函数，接收动态的亮色和暗色主题
                final lightColorScheme = // 定义亮色主题的颜色方案
                    themeProvider.lightColorScheme ?? // 优先使用 ThemeProvider 中的亮色主题
                        lightDynamic ?? // 其次使用系统动态生成的亮色主题
                        ColorScheme.fromSeed(
                          // 最后使用基于种子颜色生成的默认亮色主题
                          seedColor: Colors.lightBlue, // 种子颜色
                          brightness: Brightness.light, // 亮度为亮色
                        );
                final darkColorScheme = themeProvider.darkColorScheme ?? // 定义暗色主题的颜色方案
                    darkDynamic ?? // 优先使用 ThemeProvider 中的暗色主题
                    ColorScheme.fromSeed(
                      // 其次使用系统动态生成的暗色主题
                      seedColor: Colors.lightBlue, // 最后使用基于种子颜色生成的默认暗色主题
                      brightness: Brightness.dark, // 亮度为暗色
                    );

                final baseTextTheme = Typography.dense2021 // 定义基础文本主题
                    .copyWith(
                      // 复制并修改默认文本样式
                      bodyLarge: const TextStyle(fontWeight: FontWeight.bold), // 设置 bodyLarge 文本加粗
                      bodyMedium: const TextStyle(fontWeight: FontWeight.bold), // 设置 bodyMedium 文本加粗
                      bodySmall: const TextStyle(fontWeight: FontWeight.bold), // 设置 bodySmall 文本加粗
                      displayLarge: const TextStyle(fontWeight: FontWeight.bold), // 设置 displayLarge 文本加粗
                      displayMedium: const TextStyle(fontWeight: FontWeight.bold), // 设置 displayMedium 文本加粗
                      displaySmall: const TextStyle(fontWeight: FontWeight.bold), // 设置 displaySmall 文本加粗
                      headlineLarge: const TextStyle(fontWeight: FontWeight.bold), // 设置 headlineLarge 文本加粗
                      headlineMedium: const TextStyle(fontWeight: FontWeight.bold), // 设置 headlineMedium 文本加粗
                      headlineSmall: const TextStyle(fontWeight: FontWeight.bold), // 设置 headlineSmall 文本加粗
                      labelLarge: const TextStyle(fontWeight: FontWeight.bold), // 设置 labelLarge 文本加粗
                      labelMedium: const TextStyle(fontWeight: FontWeight.bold), // 设置 labelMedium 文本加粗
                      labelSmall: const TextStyle(fontWeight: FontWeight.bold), // 设置 labelSmall 文本加粗
                      titleLarge: const TextStyle(fontWeight: FontWeight.bold), // 设置 titleLarge 文本加粗
                      titleMedium: const TextStyle(fontWeight: FontWeight.bold), // 设置 titleMedium 文本加粗
                      titleSmall: const TextStyle(fontWeight: FontWeight.bold), // 设置 titleSmall 文本加粗
                    )
                    .apply(fontFamily: 'MiSans-Bold'); // 应用全局字体 'MiSans-Bold'

                return MaterialApp(
                  // 返回 MaterialApp 组件
                  title: 'Music Player', // 应用标题
                  theme: ThemeData(
                    // 设置亮色主题
                    colorScheme: lightColorScheme, // 使用定义的亮色颜色方案
                    useMaterial3: true, // 启用 Material 3 设计
                    fontFamily: 'MiSans-Bold', // 设置全局字体
                    textTheme: baseTextTheme, // 使用定义的基础文本主题
                    visualDensity: VisualDensity.adaptivePlatformDensity, // 设置视觉密度以适应不同平台
                    appBarTheme: AppBarTheme(
                      // 设置应用栏主题
                      centerTitle: true, // 标题居中
                      elevation: 0, // 海拔高度为 0 (无阴影)
                      backgroundColor: lightColorScheme.surface, // 背景颜色使用亮色主题的 surface 颜色
                      surfaceTintColor: Colors.transparent, // 表面着色为透明
                      systemOverlayStyle: SystemUiOverlayStyle(
                        // 设置系统覆盖层样式 (状态栏)
                        statusBarColor: Colors.transparent, // 状态栏背景透明
                        statusBarIconBrightness: Brightness.dark, // 状态栏图标为深色
                        statusBarBrightness: Brightness.light, // 状态栏内容区域亮度 (iOS)
                        systemNavigationBarColor: lightColorScheme.surface, // 导航栏背景颜色使用亮色主题的 surface 颜色
                        systemNavigationBarIconBrightness: Brightness.dark, // 导航栏图标为深色
                        systemNavigationBarDividerColor: Colors.transparent, // 导航栏分割线颜色为透明
                      ),
                    ),
                  ),
                  darkTheme: ThemeData(
                    // 设置暗色主题
                    colorScheme: darkColorScheme, // 使用定义的暗色颜色方案
                    useMaterial3: true, // 启用 Material 3 设计
                    fontFamily: 'MiSans-Bold', // 设置全局字体
                    textTheme: baseTextTheme, // 使用定义的基础文本主题
                    visualDensity: VisualDensity.adaptivePlatformDensity, // 设置视觉密度以适应不同平台
                    appBarTheme: AppBarTheme(
                      // 设置应用栏主题
                      centerTitle: true, // 标题居中
                      elevation: 0, // 海拔高度为 0 (无阴影)
                      backgroundColor: darkColorScheme.surface, // 背景颜色使用暗色主题的 surface 颜色
                      surfaceTintColor: Colors.transparent, // 表面着色为透明
                      systemOverlayStyle: SystemUiOverlayStyle(
                        // 设置系统覆盖层样式 (状态栏)
                        statusBarColor: Colors.transparent, // 状态栏背景透明
                        statusBarIconBrightness: Brightness.light, // 状态栏图标为浅色
                        statusBarBrightness: Brightness.dark, // 状态栏内容区域亮度 (iOS)
                        systemNavigationBarColor: darkColorScheme.surface, // 导航栏背景颜色使用暗色主题的 surface 颜色
                        systemNavigationBarIconBrightness: Brightness.light, // 导航栏图标为浅色
                        systemNavigationBarDividerColor: Colors.transparent, // 导航栏分割线颜色为透明
                      ),
                    ),
                  ),
                  themeMode: themeProvider.themeMode, // 从 ThemeProvider 获取当前主题模式 (亮色/暗色/跟随系统)
                  home: const HomeScreen(), // 设置主屏幕
                  debugShowCheckedModeBanner: false, // 移除调试模式下的横幅
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
  // 用于提供 TickerProvider 的 StatefulWidget
  final Widget child; // 子 Widget
  const ThemeProviderWrapper({super.key, required this.child}); // 构造函数

  @override // 重写 createState 方法
  State<ThemeProviderWrapper> createState() => _ThemeProviderWrapperState(); // 创建状态对象
}

class _ThemeProviderWrapperState extends State<ThemeProviderWrapper> with TickerProviderStateMixin {
  // ThemeProviderWrapper 的状态类，混入 TickerProviderStateMixin
  late ThemeProvider _themeProvider; // 声明 ThemeProvider 实例

  @override // 重写 initState 方法
  void initState() {
    // 初始化状态
    super.initState(); // 调用父类的 initState
    _themeProvider = ThemeProvider(vsync: this); // 初始化 ThemeProvider，并传入 TickerProvider
  }

  @override // 重写 dispose 方法
  void dispose() {
    // 销毁状态
    _themeProvider.dispose(); // 销毁 ThemeProvider
    super.dispose(); // 调用父类的 dispose
  }

  @override // 重写 build 方法
  Widget build(BuildContext context) {
    // 构建 Widget
    return ChangeNotifierProvider.value(
      // 使用 ChangeNotifierProvider.value 来提供已创建的 _themeProvider
      value: _themeProvider, // 提供 _themeProvider 实例
      child: widget.child, // 返回子 Widget
    );
  }
}
