import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'duplicate_songs_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        children: <Widget>[
          const Text('外观', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            clipBehavior: Clip.antiAlias, // 新增，确保圆角生效
            child: InkWell(
              borderRadius: BorderRadius.circular(12), // 新增，涟漪和悬停圆角
              onTap: () {
                _showThemeDialog(context);
              },
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.color_lens, color: Colors.blueAccent),
                    title: const Text('主题设置'),
                    subtitle: Text(_getCurrentThemeModeText(context)), // 新增副标题显示当前主题模式
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16), // Added spacing
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _showPlayerBackgroundStyleDialog(context);
              },
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.photo_size_select_actual_outlined, color: Colors.purpleAccent),
                    title: const Text('播放页背景风格'),
                    subtitle: Text(_getCurrentPlayerBackgroundStyleText(context)), // Display current style
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16), // Added spacing
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _showFontFamilyDialog(context);
              },
              child: Consumer<ThemeProvider>(
                builder: (context, themeProvider, child) {
                  return ListTile(
                    leading: const Icon(Icons.font_download, color: Colors.orangeAccent),
                    title: const Text('字体设置'),
                    subtitle: Text(_getCurrentFontFamilyText(context)),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('功能', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DuplicateSongsScreen(),
                  ),
                );
              },
              child: const ListTile(
                leading: Icon(Icons.library_music, color: Colors.deepOrange),
                title: Text('重复歌曲管理'),
                subtitle: Text('检测并清理音乐库中的重复歌曲'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('关于', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            clipBehavior: Clip.antiAlias, // 新增，确保圆角生效
            child: InkWell(
              borderRadius: BorderRadius.circular(12), // 新增，涟漪和悬停圆角
              onTap: () {
                showDialog<void>(
                  context: context,
                  builder: (BuildContext context) {
                    return Theme(
                      data: theme.copyWith(
                        textTheme: theme.textTheme.copyWith(
                          headlineSmall: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      child: AboutDialog(
                        applicationName: 'Meloria Music Player',
                        applicationVersion: 'v0.1.0',
                        applicationIcon: Icon(Icons.music_note, size: 40, color: theme.primaryColor),
                        children: [
                          const Text(
                              '一个简洁美观的本地音乐播放器。\n作者：老官童鞋gogo\n\nv0.1.0版本更新内容：\n1. 重新设计播放逻辑：\n\t1）添加播放列表功能，将音乐库列表循环改为播放列表循环。\n\t2）重新设计随机播放逻辑，使其切换歌曲时更符合常用逻辑。\n\t3）重新设计历史记录的播放与更新逻辑。\n2. 重新设计 歌单 页面。\n3. 优化设置页面显示效果与部分弹窗的显示效果。\n4. 优化歌词滚动的时间节点。\n'),
                          const SizedBox(height: 8),
                          const Text('作者的博客：'),
                          InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            onTap: () async {
                              final Uri url = Uri.parse('https://www.laoguantx.top');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: Text(
                              'https://www.laoguantx.top',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text('作者的Github主页：'),
                          InkWell(
                            mouseCursor: SystemMouseCursors.click,
                            onTap: () async {
                              final Uri url = Uri.parse('https://github.com/laoguanTX');
                              if (await canLaunchUrl(url)) {
                                await launchUrl(url);
                              }
                            },
                            child: Text(
                              'https://github.com/laoguanTX',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.green),
                title: const Text('关于'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _showKeyboardShortcutsDialog(context);
              },
              child: const ListTile(
                leading: Icon(Icons.keyboard_alt_outlined, color: Colors.blueGrey),
                title: Text('快捷键说明'),
                trailing: Icon(Icons.chevron_right),
              ),
            ),
          ),
          // 可继续添加更多设置项
        ],
      ),
    );
  }
}

// 新增：显示主题选择对话框
void _showThemeDialog(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('选择主题模式', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<ThemeMode>(
              title: const Text('跟随系统'),
              value: ThemeMode.system,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.updateThemeMode(value); // MODIFIED: Changed to updateThemeMode
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('亮色模式'),
              value: ThemeMode.light,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.updateThemeMode(value); // MODIFIED: Changed to updateThemeMode
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: const Text('暗黑模式'),
              value: ThemeMode.dark,
              groupValue: themeProvider.themeMode,
              onChanged: (ThemeMode? value) {
                if (value != null) {
                  themeProvider.updateThemeMode(value); // MODIFIED: Changed to updateThemeMode
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

// Helper function to get display text for current player background style
String _getCurrentPlayerBackgroundStyleText(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false); // MODIFIED: Uncommented and used
  switch (themeProvider.playerBackgroundStyle) {
    case PlayerBackgroundStyle.solidGradient:
      return '纯色渐变';
    case PlayerBackgroundStyle.albumArtFrostedGlass:
      return '专辑图片毛玻璃背景';
  }
}

// 新增：显示播放页背景风格选择对话框
void _showPlayerBackgroundStyleDialog(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  PlayerBackgroundStyle currentStyle = themeProvider.playerBackgroundStyle; // MODIFIED: Used themeProvider

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('选择播放页背景风格', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<PlayerBackgroundStyle>(
              title: const Text('纯色渐变'),
              value: PlayerBackgroundStyle.solidGradient,
              groupValue: currentStyle,
              onChanged: (PlayerBackgroundStyle? value) {
                if (value != null) {
                  themeProvider.updatePlayerBackgroundStyle(value); // MODIFIED: Changed to updatePlayerBackgroundStyle
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<PlayerBackgroundStyle>(
              title: const Text('专辑图片毛玻璃背景'),
              value: PlayerBackgroundStyle.albumArtFrostedGlass,
              groupValue: currentStyle,
              onChanged: (PlayerBackgroundStyle? value) {
                if (value != null) {
                  themeProvider.updatePlayerBackgroundStyle(value); // MODIFIED: Changed to updatePlayerBackgroundStyle
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

// Helper function to get display text for current font family
String _getCurrentFontFamilyText(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  switch (themeProvider.fontFamily) {
    case FontFamily.system:
      return '系统字体';
    case FontFamily.miSans:
      return 'MiSans';
    case FontFamily.apple:
      return '苹方';
    case FontFamily.harmonyosSans:
      return 'HarmonyOS-Sans';
  }
}

// 新增：显示字体族选择对话框
void _showFontFamilyDialog(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  FontFamily currentFont = themeProvider.fontFamily;

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text('选择字体', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<FontFamily>(
              title: const Text('系统字体'),
              subtitle: const Text('使用系统默认字体'),
              value: FontFamily.system,
              groupValue: currentFont,
              onChanged: (FontFamily? value) {
                if (value != null) {
                  themeProvider.updateFontFamily(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<FontFamily>(
              title: const Text('MiSans'),
              subtitle: const Text('小米字体'),
              value: FontFamily.miSans,
              groupValue: currentFont,
              onChanged: (FontFamily? value) {
                if (value != null) {
                  themeProvider.updateFontFamily(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<FontFamily>(
              title: const Text('苹方'),
              subtitle: const Text('苹果字体'),
              value: FontFamily.apple,
              groupValue: currentFont,
              onChanged: (FontFamily? value) {
                if (value != null) {
                  themeProvider.updateFontFamily(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<FontFamily>(
              title: const Text('HarmonyOS-Sans'),
              subtitle: const Text('华为字体'),
              value: FontFamily.harmonyosSans,
              groupValue: currentFont,
              onChanged: (FontFamily? value) {
                if (value != null) {
                  themeProvider.updateFontFamily(value);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
      );
    },
  );
}

void _showKeyboardShortcutsDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final theme = Theme.of(context);
      return AlertDialog(
        title: Text('快捷键说明', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: SizedBox(
          width: 350,
          child: ListView(
            shrinkWrap: true,
            children: const [
              ListTile(title: Text('播放/暂停'), subtitle: Text('空格键 或 媒体播放/暂停键')),
              ListTile(title: Text('下一曲'), subtitle: Text('媒体下一曲键 或 Ctrl + 右方向键')),
              ListTile(title: Text('上一曲'), subtitle: Text('媒体上一曲键 或 Ctrl + 左方向键')),
              ListTile(title: Text('快进 5 秒'), subtitle: Text('右方向键')),
              ListTile(title: Text('快退 5 秒'), subtitle: Text('左方向键')),
              ListTile(title: Text('增加音量'), subtitle: Text('上方向键')),
              ListTile(title: Text('降低音量'), subtitle: Text('下方向键')),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('关闭'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

// Helper function to get display text for current theme mode
String _getCurrentThemeModeText(BuildContext context) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  switch (themeProvider.themeMode) {
    case ThemeMode.system:
      // 当选择跟随系统时，显示系统当前实际使用的模式
      final brightness = MediaQuery.of(context).platformBrightness;
      return brightness == Brightness.dark ? '跟随系统 (暗黑模式)' : '跟随系统 (亮色模式)';
    case ThemeMode.light:
      return '亮色模式';
    case ThemeMode.dark:
      return '暗黑模式';
  }
}
