import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // 新增导入
import '../providers/theme_provider.dart'; // 新增导入

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
              child: ListTile(
                leading: const Icon(Icons.color_lens, color: Colors.blueAccent),
                title: const Text('主题设置'),
                trailing: const Icon(Icons.chevron_right),
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
              child: ListTile(
                leading: const Icon(Icons.photo_size_select_actual_outlined, color: Colors.purpleAccent),
                title: const Text('播放页背景风格'),
                subtitle: Text(_getCurrentPlayerBackgroundStyleText(context)), // Display current style
                trailing: const Icon(Icons.chevron_right),
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
                showAboutDialog(
                  context: context,
                  applicationName: '音乐播放器',
                  applicationVersion: 'v1.0.0',
                  applicationIcon: Icon(Icons.music_note, size: 40, color: theme.primaryColor),
                  children: [
                    const Text('一个简洁美观的本地音乐播放器。\n作者：老官童鞋gogo'),
                  ],
                );
              },
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.green),
                title: const Text('关于'),
                trailing: const Icon(Icons.chevron_right),
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
        title: const Text('选择主题模式'),
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
        title: const Text('选择播放页背景风格'),
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
