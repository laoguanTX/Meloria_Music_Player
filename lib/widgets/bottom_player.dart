// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';

class BottomPlayer extends StatelessWidget {
  const BottomPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final song = musicProvider.currentSong;
        if (song == null) return const SizedBox.shrink();

        double totalMillis = musicProvider.totalDuration.inMilliseconds.toDouble();
        if (totalMillis <= 0) {
          totalMillis = 1.0; // Avoid division by zero or invalid range for Slider
        }
        double currentMillis = musicProvider.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMillis);

        return Container(
          margin: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 8,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => const PlayerScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const begin = Offset(0.0, 1.0);
                      const end = Offset.zero;
                      const curve = Curves.easeOutCubic;
                      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                      final offsetAnimation = animation.drive(tween);
                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                    transitionDuration: const Duration(milliseconds: 300), // 与 home_screen 动画时长一致
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Progress indicator
                    Row(
                      children: [
                        Text(
                          _formatDuration(musicProvider.currentPosition),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Expanded(
                          child: Slider(
                            value: currentMillis,
                            min: 0.0,
                            max: totalMillis,
                            onChanged: (value) {
                              // Seek to the new position
                              if (musicProvider.totalDuration.inMilliseconds > 0) {
                                musicProvider.seekTo(Duration(milliseconds: value.toInt()));
                              }
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                        ),
                        Text(
                          _formatDuration(musicProvider.totalDuration),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        // Album art
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.albumArt != null
                                ? AspectRatio(
                                    aspectRatio: 1.0, // 强制正方形比例
                                    child: Image.memory(
                                      song.albumArt!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.music_note,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Song info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                song.artist,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Control buttons
                        // 音量控制修改: 不再使用Expanded包裹，使其和播放按钮一起被右推
                        Row(
                          mainAxisSize: MainAxisSize.min, // 确保此Row只占据必要空间
                          children: [
                            IconButton(
                              icon: Icon(
                                musicProvider.volume == 0
                                    ? Icons.volume_off
                                    : musicProvider.volume < 0.5
                                        ? Icons.volume_down
                                        : Icons.volume_up,
                              ),
                              onPressed: () {
                                musicProvider.toggleMute(); // 点击喇叭切换静音
                              },
                            ),
                            SizedBox(
                              width: 150, // 设置固定宽度，作为"长度减半"的近似实现
                              child: Slider(
                                value: musicProvider.volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (value) {
                                  musicProvider.setVolume(value);
                                },
                                activeColor: Theme.of(context).colorScheme.primary,
                                inactiveColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous),
                          onPressed: musicProvider.previousSong,
                        ),
                        IconButton(
                          icon: Icon(
                            musicProvider.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
                          ),
                          iconSize: 40,
                          onPressed: musicProvider.playPause,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next),
                          onPressed: musicProvider.nextSong,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatDuration(Duration duration) {
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final minutes = twoDigits(duration.inMinutes.remainder(60));
  final seconds = twoDigits(duration.inSeconds.remainder(60));
  return '$minutes:$seconds';
}
