// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 新增导入

// 新增：字体类型枚举
enum FontFamily {
  system, // 系统字体
  miSans, // MiSans字体
  apple, // 苹方字体
  harmonyosSans, //HarmonyOSSans字体
}

class ThemeProvider extends ChangeNotifier {
  final TickerProvider vsync; // 新增：用于 AnimationController
  late AnimationController _animationController;
  Animation<Color?>? _colorAnimation;

  Color _seedColor = _defaultColor; // 当前稳定的种子颜色
  ColorScheme? _lightColorScheme;
  ColorScheme? _darkColorScheme;
  ThemeMode _themeMode = ThemeMode.system; // 新增：主题模式
  PlayerBackgroundStyle _playerBackgroundStyle = PlayerBackgroundStyle.solidGradient; // 新增：播放页背景风格
  FontFamily _fontFamily = FontFamily.miSans; // 新增：字体族

  static const Color _defaultColor = Color(0xFF87CEEB); // 天蓝色
  static const String _themeModeKey = 'theme_mode'; // 新增：持久化key
  static const String _playerBackgroundStyleKey = 'player_background_style'; // 新增：持久化key
  static const String _fontFamilyKey = 'font_family'; // 新增：字体族持久化key

  ColorScheme? get lightColorScheme => _lightColorScheme;
  ColorScheme? get darkColorScheme => _darkColorScheme;
  Color get dominantColor => _seedColor; // 返回稳定的种子颜色
  ThemeMode get themeMode => _themeMode; // 新增：获取当前主题模式
  PlayerBackgroundStyle get playerBackgroundStyle => _playerBackgroundStyle; // 新增：获取播放页背景风格
  FontFamily get fontFamily => _fontFamily; // 新增：获取当前字体族

  // 新增：获取当前字体族的字体名称
  String? get fontFamilyName {
    switch (_fontFamily) {
      case FontFamily.system:
        return null; // 使用系统默认字体
      case FontFamily.miSans:
        return 'MiSans-Bold';
      case FontFamily.apple:
        return '苹方';
      case FontFamily.harmonyosSans:
        return 'HarmonyOS-Sans';
    }
  }

  // 新增：获取当前主题模式下的合适前景色
  Color get foregroundColor {
    final Brightness currentBrightness;
    switch (_themeMode) {
      case ThemeMode.light:
        currentBrightness = Brightness.light;
        break;
      case ThemeMode.dark:
        currentBrightness = Brightness.dark;
        break;
      case ThemeMode.system:
        currentBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        break;
    }
    return currentBrightness == Brightness.dark ? Colors.white : Colors.black;
  }

  ThemeProvider({required this.vsync}) {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: vsync,
    );

    // 初始化主题颜色方案，这将是第一次动画的起始状态
    // _seedColor 默认为 _defaultColor
    _lightColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light);
    _darkColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);

    _animationController.addListener(() {
      if (_colorAnimation != null && _colorAnimation!.value != null) {
        final animatedColor = _colorAnimation!.value!;
        _lightColorScheme = ColorScheme.fromSeed(
          seedColor: animatedColor,
          brightness: Brightness.light,
        );
        _darkColorScheme = ColorScheme.fromSeed(
          seedColor: animatedColor,
          brightness: Brightness.dark,
        );
        notifyListeners();
      }
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // 动画完成后，更新稳定种子颜色并更新系统UI
        if (_colorAnimation?.value != null) {
          _seedColor = _colorAnimation!.value!;
        }
        _updateSystemUiOverlay();
      } else if (status == AnimationStatus.dismissed) {
        // 如果动画被取消或重置，确保使用当前_seedColor
        _lightColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light);
        _darkColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
        _updateSystemUiOverlay();
        notifyListeners();
      }
    });

    // 显式调用 _setDefaultTheme() 来设置并可能动画到初始主题。
    // 这确保了 _animationController 在被 _applyThemeChange 使用前已初始化。
    _setDefaultTheme();

    // 初始时调用一次，确保系统UI基于初始（可能是动画前的）主题正确更新。
    // 如果 _setDefaultTheme 启动了动画，动画状态监听器也会调用 _updateSystemUiOverlay。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSystemUiOverlay();
      _loadThemeMode(); // 新增：启动时加载主题模式
      _loadPlayerBackgroundStyle(); // 新增：启动时加载播放页背景风格
      _loadFontFamily(); // 新增：启动时加载字体族
    });
  }

  // 新增：保存主题模式到本地
  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, _themeMode.index);
  }

  // 新增：从本地加载主题模式
  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    } else {
      _themeMode = ThemeMode.system; // 默认值
    }
    notifyListeners();
    _updateSystemUiOverlay(); // 更新系统UI以反映加载的主题模式
  }

  // MODIFIED: Renamed to avoid conflict
  void updateThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeMode(); // 保存到本地
      notifyListeners();
      _updateSystemUiOverlay(); // 更新系统UI
    }
  }

  // 新增：保存播放页背景风格到本地
  Future<void> _savePlayerBackgroundStyle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playerBackgroundStyleKey, _playerBackgroundStyle.index);
  }

  // 新增：从本地加载播放页背景风格
  Future<void> _loadPlayerBackgroundStyle() async {
    final prefs = await SharedPreferences.getInstance();
    final styleIndex = prefs.getInt(_playerBackgroundStyleKey);
    if (styleIndex != null && styleIndex >= 0 && styleIndex < PlayerBackgroundStyle.values.length) {
      _playerBackgroundStyle = PlayerBackgroundStyle.values[styleIndex];
    } else {
      _playerBackgroundStyle = PlayerBackgroundStyle.solidGradient; // 默认值
    }
    notifyListeners();
  }

  // MODIFIED: Renamed to avoid conflict
  void updatePlayerBackgroundStyle(PlayerBackgroundStyle style) {
    if (_playerBackgroundStyle != style) {
      _playerBackgroundStyle = style;
      _savePlayerBackgroundStyle(); // 保存到本地
      notifyListeners();
    }
  }

  // 新增：保存字体族到本地
  Future<void> _saveFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontFamilyKey, _fontFamily.index);
  }

  // 新增：从本地加载字体族
  Future<void> _loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    final fontFamilyIndex = prefs.getInt(_fontFamilyKey);
    if (fontFamilyIndex != null && fontFamilyIndex >= 0 && fontFamilyIndex < FontFamily.values.length) {
      _fontFamily = FontFamily.values[fontFamilyIndex];
    } else {
      _fontFamily = FontFamily.miSans; // 默认值
    }
    notifyListeners();
  }

  // 新增：更新字体族
  void updateFontFamily(FontFamily fontFamily) {
    if (_fontFamily != fontFamily) {
      _fontFamily = fontFamily;
      _saveFontFamily(); // 保存到本地
      notifyListeners();
    }
  }

  void _applyThemeChange(Color newSeedColor) {
    if (_animationController.isAnimating) {
      _animationController.stop(); // 停止当前动画
    }

    // 设置动画的起始和结束颜色
    _colorAnimation = ColorTween(
      begin: _seedColor, // 当前稳定颜色作为动画起点
      end: newSeedColor,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward(from: 0.0); // 从头开始播放动画
    // _seedColor 将在动画完成时更新为 newSeedColor
  }

  void _updateSystemUiOverlay() {
    // 根据当前主题模式确定亮度
    final Brightness currentBrightness;
    switch (_themeMode) {
      case ThemeMode.light:
        currentBrightness = Brightness.light;
        break;
      case ThemeMode.dark:
        currentBrightness = Brightness.dark;
        break;
      case ThemeMode.system:
        currentBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        break;
    }

    // 根据亮度设置系统UI叠加层样式
    final systemUiOverlayStyle = currentBrightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent, // 透明状态栏
            systemNavigationBarColor: _darkColorScheme?.background ?? Colors.black, // 深色导航栏背景
            systemNavigationBarIconBrightness: Brightness.light, // 浅色导航栏图标
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent, // 透明状态栏
            systemNavigationBarColor: _lightColorScheme?.background ?? Colors.white, // 浅色导航栏背景
            systemNavigationBarIconBrightness: Brightness.dark, // 深色导航栏图标
          );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  void _setDefaultTheme() {
    _applyThemeChange(_defaultColor);
  }

  // 从专辑图片提取颜色并更新主题
  Future<void> updateThemeFromAlbumArt(Uint8List? albumArtData) async {
    if (albumArtData == null) {
      _setDefaultTheme();
      return;
    }
    try {
      final imageProvider = MemoryImage(albumArtData);
      final paletteGenerator = await PaletteGenerator.fromImageProvider(
        imageProvider,
        maximumColorCount: 20,
      );

      Color newDominantColor =
          paletteGenerator.dominantColor?.color ?? paletteGenerator.vibrantColor?.color ?? paletteGenerator.mutedColor?.color ?? _defaultColor;

      final hsl = HSLColor.fromColor(newDominantColor);
      if (hsl.lightness < 0.2) {
        // 调整阈值，避免颜色过暗
        newDominantColor = hsl.withLightness(0.4).toColor();
      } else if (hsl.lightness > 0.85) {
        // 调整阈值，避免颜色过亮
        newDominantColor = hsl.withLightness(0.65).toColor();
      }

      // 确保颜色不会与背景过于接近，增加对比度
      // 这是一个简化的对比度检查，可能需要更复杂的逻辑
      final double luminance = newDominantColor.computeLuminance();
      if (luminance < 0.1 || luminance > 0.9) {
        // 如果亮度过低或过高
        // 尝试从调色板中选择另一个颜色
        newDominantColor = paletteGenerator.lightVibrantColor?.color ?? paletteGenerator.darkVibrantColor?.color ?? _defaultColor;
        // 再次调整亮度
        final newHsl = HSLColor.fromColor(newDominantColor);
        if (newHsl.lightness < 0.2) {
          newDominantColor = newHsl.withLightness(0.4).toColor();
        } else if (newHsl.lightness > 0.85) newDominantColor = newHsl.withLightness(0.65).toColor();
      }

      _applyThemeChange(newDominantColor);
    } catch (e) {
      // print('提取专辑颜色时出错: $e');
      // _setDefaultTheme();
    }
  }

  // 重置为默认主题
  void resetToDefault() {
    _setDefaultTheme();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// 新增：播放页背景风格枚举
enum PlayerBackgroundStyle {
  solidGradient, // 纯色渐变
  albumArtFrostedGlass, // 专辑图片毛玻璃背景
}
