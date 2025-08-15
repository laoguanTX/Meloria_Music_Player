// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FontFamily {
  system,
  miSans,
  apple,
  harmonyosSans,
}

class ThemeProvider extends ChangeNotifier {
  final TickerProvider vsync;
  late AnimationController _animationController;
  Animation<Color?>? _colorAnimation;

  Color _seedColor = _defaultColor;
  ColorScheme? _lightColorScheme;
  ColorScheme? _darkColorScheme;
  ThemeMode _themeMode = ThemeMode.system;
  PlayerBackgroundStyle _playerBackgroundStyle = PlayerBackgroundStyle.solidGradient;
  FontFamily _fontFamily = FontFamily.miSans;

  static const Color _defaultColor = Color(0xFF87CEEB);
  static const String _themeModeKey = 'theme_mode';
  static const String _playerBackgroundStyleKey = 'player_background_style';
  static const String _fontFamilyKey = 'font_family';

  ColorScheme? get lightColorScheme => _lightColorScheme;
  ColorScheme? get darkColorScheme => _darkColorScheme;
  Color get dominantColor => _seedColor;
  ThemeMode get themeMode => _themeMode;
  PlayerBackgroundStyle get playerBackgroundStyle => _playerBackgroundStyle;
  FontFamily get fontFamily => _fontFamily;

  String? get fontFamilyName {
    switch (_fontFamily) {
      case FontFamily.system:
        return null;
      case FontFamily.miSans:
        return 'MiSans-Bold';
      case FontFamily.apple:
        return '苹方';
      case FontFamily.harmonyosSans:
        return 'HarmonyOS-Sans';
    }
  }

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
        if (_colorAnimation?.value != null) {
          _seedColor = _colorAnimation!.value!;
        }
        _updateSystemUiOverlay();
      } else if (status == AnimationStatus.dismissed) {
        _lightColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.light);
        _darkColorScheme = ColorScheme.fromSeed(seedColor: _seedColor, brightness: Brightness.dark);
        _updateSystemUiOverlay();
        notifyListeners();
      }
    });

    _setDefaultTheme();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateSystemUiOverlay();
      _loadThemeMode();
      _loadPlayerBackgroundStyle();
      _loadFontFamily();
    });
  }

  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, _themeMode.index);
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
    _updateSystemUiOverlay();
  }

  void updateThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      _saveThemeMode();
      notifyListeners();
      _updateSystemUiOverlay();
    }
  }

  Future<void> _savePlayerBackgroundStyle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_playerBackgroundStyleKey, _playerBackgroundStyle.index);
  }

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

  void updatePlayerBackgroundStyle(PlayerBackgroundStyle style) {
    if (_playerBackgroundStyle != style) {
      _playerBackgroundStyle = style;
      _savePlayerBackgroundStyle();
      notifyListeners();
    }
  }

  Future<void> _saveFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fontFamilyKey, _fontFamily.index);
  }

  Future<void> _loadFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    final fontFamilyIndex = prefs.getInt(_fontFamilyKey);
    if (fontFamilyIndex != null && fontFamilyIndex >= 0 && fontFamilyIndex < FontFamily.values.length) {
      _fontFamily = FontFamily.values[fontFamilyIndex];
    } else {
      _fontFamily = FontFamily.miSans;
    }
    notifyListeners();
  }

  void updateFontFamily(FontFamily fontFamily) {
    if (_fontFamily != fontFamily) {
      _fontFamily = fontFamily;
      _saveFontFamily();
      notifyListeners();
    }
  }

  void _applyThemeChange(Color newSeedColor) {
    if (_animationController.isAnimating) {
      _animationController.stop();
    }

    _colorAnimation = ColorTween(
      begin: _seedColor,
      end: newSeedColor,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward(from: 0.0);
  }

  void _updateSystemUiOverlay() {
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

    final systemUiOverlayStyle = currentBrightness == Brightness.dark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _darkColorScheme?.background ?? Colors.black,
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: _lightColorScheme?.background ?? Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          );

    SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
  }

  void _setDefaultTheme() {
    _applyThemeChange(_defaultColor);
  }

  Future<void> updateThemeFromAlbumArt(Uint8List? albumArtData) async {
    if (albumArtData == null) {
      _setDefaultTheme();
      return;
    }
    final imageProvider = MemoryImage(albumArtData);
    final paletteGenerator = await PaletteGenerator.fromImageProvider(
      imageProvider,
      maximumColorCount: 20,
    );

    Color newDominantColor =
        paletteGenerator.dominantColor?.color ?? paletteGenerator.vibrantColor?.color ?? paletteGenerator.mutedColor?.color ?? _defaultColor;

    final hsl = HSLColor.fromColor(newDominantColor);
    if (hsl.lightness < 0.2) {
      newDominantColor = hsl.withLightness(0.4).toColor();
    } else if (hsl.lightness > 0.85) {
      newDominantColor = hsl.withLightness(0.65).toColor();
    }

    final double luminance = newDominantColor.computeLuminance();
    if (luminance < 0.1 || luminance > 0.9) {
      newDominantColor = paletteGenerator.lightVibrantColor?.color ?? paletteGenerator.darkVibrantColor?.color ?? _defaultColor;
      final newHsl = HSLColor.fromColor(newDominantColor);
      if (newHsl.lightness < 0.2) {
        newDominantColor = newHsl.withLightness(0.4).toColor();
      } else if (newHsl.lightness > 0.85) newDominantColor = newHsl.withLightness(0.65).toColor();
    }

    _applyThemeChange(newDominantColor);
  }

  void resetToDefault() {
    _setDefaultTheme();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

enum PlayerBackgroundStyle {
  solidGradient,
  albumArtFrostedGlass,
}
