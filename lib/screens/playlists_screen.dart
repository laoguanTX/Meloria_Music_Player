import 'package:flutter/material.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
          color: Colors.transparent,
          child: Builder(builder: (context) {
            final ThemeData theme = Theme.of(context);
            final AppBarTheme appBarTheme = AppBarTheme.of(context);
            final TextStyle? titleStyle = appBarTheme.titleTextStyle ?? theme.primaryTextTheme.titleLarge ?? theme.textTheme.titleLarge;

            return NavigationToolbar(
              middle: DefaultTextStyle(
                style: titleStyle ?? TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                child: const Text('播放列表'),
              ),
              centerMiddle: true,
              middleSpacing: NavigationToolbar.kMiddleSpacing,
            );
          }),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.playlist_play_outlined,
              size: 80,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              '播放列表功能',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '即将推出...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
