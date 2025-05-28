// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui; // Added for lerpDouble
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../widgets/player_custom_status_bar.dart'; // 导入 PlayerCustomStatusBar

class PlayerScreen extends StatefulWidget {
  // Changed to StatefulWidget
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with TickerProviderStateMixin {
  // Added TickerProviderStateMixin
  late AnimationController _progressAnimationController;
  double _sliderDisplayValue = 0.0; // Value shown on the slider
  double _sliderTargetValue = 0.0; // Target value from MusicProvider
  double _animationStartValueForLerp =
      0.0; // Start value for lerp interpolation

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200), // Animation duration
    )..addListener(() {
        if (mounted) {
          // Use addPostFrameCallback to avoid calling setState during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              // Re-check mounted as callback is asynchronous
              setState(() {
                _sliderDisplayValue = ui.lerpDouble(_animationStartValueForLerp,
                    _sliderTargetValue, _progressAnimationController.value)!;
              });
            }
          });
        }
      });
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    // Restore system UI if it was changed for this screen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Hides system navigation bar - this was already here
    // SystemChrome.setEnabledSystemUIMode(
    //   SystemUiMode.manual,
    //   overlays: [SystemUiOverlay.top],
    // ); // This will be handled by CustomStatusBar or needs adjustment

    return PlayerCustomStatusBar(
      // 修改为 PlayerCustomStatusBar
      // Wrap with CustomStatusBar
      transparent: true, // Make status bar transparent
      applyChildTopPadding: false, // Set to false for PlayerScreen
      actions: [
        // Pass the more_vert icon button as an action
        IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showPlayerOptions(context),
          tooltip: '更多选项',
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        ),
      ],
      child: Scaffold(
        // appBar: AppBar( // Remove original AppBar
        //   backgroundColor: Colors.transparent,
        //   elevation: 0,
        //   leading: IconButton( // This is now handled by CustomStatusBar's back button
        //     icon: const Icon(Icons.expand_more),
        //     onPressed: () => Navigator.pop(context),
        //   ),
        //   actions: [ // This should be passed to CustomStatusBar or handled differently
        //     IconButton(
        //       icon: const Icon(Icons.more_vert),
        //       onPressed: () {
        //         _showPlayerOptions(context);
        //       },
        //     ),
        //   ],
        // ),
        extendBodyBehindAppBar:
            true, // Keep this if CustomStatusBar is transparent
        body: Consumer<MusicProvider>(
          builder: (context, musicProvider, child) {
            final song = musicProvider.currentSong;
            if (song == null) {
              return const Center(
                child: Text('没有正在播放的歌曲'),
              );
            }

            // Debug info - was already here
            // print(\'PlayerScreen - 当前歌曲: ${song.title}\');
            // print(
            //     \'PlayerScreen - 专辑图片: ${song.albumArt != null ? \'${song.albumArt!.length} bytes\' : \'无\'}\');

            double currentActualMillis = 0.0;
            double totalMillis =
                musicProvider.totalDuration.inMilliseconds.toDouble();
            if (totalMillis <= 0) {
              totalMillis =
                  1.0; // Avoid division by zero or invalid range for Slider
            }
            currentActualMillis = musicProvider.currentPosition.inMilliseconds
                .toDouble()
                .clamp(0.0, totalMillis);

            if (_sliderTargetValue != currentActualMillis) {
              if (_progressAnimationController.isAnimating) {
                _progressAnimationController.stop();
              }
              _animationStartValueForLerp = _sliderDisplayValue;
              _sliderTargetValue = currentActualMillis;
              _progressAnimationController.forward(from: 0.0);
            } else if (!_progressAnimationController.isAnimating &&
                _sliderDisplayValue != _sliderTargetValue) {
              // Snap to target if not animating and not at target (e.g., initial or after drag)
              // Use addPostFrameCallback to avoid calling setState during build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _sliderDisplayValue = _sliderTargetValue;
                  });
                }
              });
            }

            return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.secondaryContainer,
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 80), // Space for app bar

                      // Album art
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: 1.0 / 1.0, // 强制正方形比例
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context)
                                    .colorScheme
                                    .primaryContainer,
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .shadow
                                        .withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: song.albumArt != null
                                    ? Image.memory(
                                        song.albumArt!,
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return Icon(
                                            Icons.music_note,
                                            size: 120,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onPrimaryContainer,
                                          );
                                        },
                                      )
                                    : Icon(
                                        Icons.music_note,
                                        size: 120,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimaryContainer,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Song info
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Text(
                              song.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              song.artist,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (song.album.isNotEmpty &&
                                song.album != 'Unknown Album')
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  song.album,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            // The "more options" button is conceptually part of the status bar's actions.
                            // If CustomStatusBar doesn't support actions directly,
                            // you might need to overlay it or place it differently.
                            // For now, removing the explicit Align here as CustomStatusBar should handle actions.
                            // Align(
                            //   alignment: Alignment.topRight,
                            //   child: IconButton(
                            //     icon: const Icon(Icons.more_vert),
                            //     onPressed: () {
                            //       _showPlayerOptions(context);
                            //     },
                            //     color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            //   ),
                            // )
                          ],
                        ),
                      ), // Progress slider 和 Volume slider 并排放置
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          children: [
                            // 播放进度条 (占据5/6的宽度)
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  Slider(
                                    value: _sliderDisplayValue.clamp(
                                        0.0, totalMillis),
                                    min: 0.0,
                                    max: totalMillis,
                                    onChanged: (value) {
                                      // Stop animation if it's running
                                      if (_progressAnimationController
                                          .isAnimating) {
                                        _progressAnimationController.stop();
                                      }
                                      // Update display value immediately for responsiveness
                                      if (mounted) {
                                        setState(() {
                                          _sliderDisplayValue = value;
                                        });
                                      }
                                      // Seek to the new position
                                      musicProvider.seekTo(Duration(
                                          milliseconds: value.toInt()));
                                      // Update the target value to prevent animation jump after user releases slider
                                      _sliderTargetValue = value;
                                    },
                                    onChangeStart: (_) {
                                      if (_progressAnimationController
                                          .isAnimating) {
                                        _progressAnimationController.stop();
                                      }
                                      // When user starts dragging, update the animation start value
                                      // to the current display value to ensure smooth transition if animation was running.
                                      _animationStartValueForLerp =
                                          _sliderDisplayValue;
                                    },
                                    onChangeEnd: (value) {
                                      // Optional: If you want to trigger something specific when dragging ends,
                                      // like restarting an animation if it was paused for dragging.
                                      // For now, we ensure the target is set, and if not playing,
                                      // the animation will naturally resume or stay at the new _sliderTargetValue.
                                      // If musicProvider's position updates, the existing logic will handle animation.
                                    },
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _formatDuration(
                                            musicProvider.currentPosition),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                      Text(
                                        _formatDuration(
                                            musicProvider.totalDuration),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // 音量控制条 (占据1/6的宽度)
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          musicProvider.toggleMute();
                                        },
                                        child: Icon(
                                          musicProvider.volume > 0.5
                                              ? Icons.volume_up
                                              : musicProvider.volume > 0
                                                  ? Icons.volume_down
                                                  : Icons.volume_off,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: musicProvider.volume,
                                          min: 0.0,
                                          max: 1.0,
                                          onChanged: (value) {
                                            musicProvider.setVolume(value);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    '${(musicProvider.volume * 100).round()}%',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Control buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            icon: Icon(
                              musicProvider.shuffleMode
                                  ? Icons.shuffle
                                  : Icons.shuffle_outlined,
                            ),
                            iconSize: 28,
                            color: musicProvider.shuffleMode
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            onPressed: musicProvider.toggleShuffle,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_previous),
                            iconSize: 36,
                            onPressed: musicProvider.previousSong,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            child: IconButton(
                              icon: Icon(
                                musicProvider.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                              iconSize: 32,
                              onPressed: musicProvider.playPause,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next),
                            iconSize: 36,
                            onPressed: musicProvider.nextSong,
                          ),
                          IconButton(
                            icon: Icon(
                              _getRepeatIcon(musicProvider.repeatMode),
                            ),
                            iconSize: 28,
                            color: musicProvider.repeatMode != RepeatMode.none
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            onPressed: musicProvider.toggleRepeatMode,
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ));
          },
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  IconData _getRepeatIcon(RepeatMode repeatMode) {
    switch (repeatMode) {
      case RepeatMode.none:
        return Icons.repeat_outlined;
      case RepeatMode.all:
        return Icons.repeat;
      case RepeatMode.one:
        return Icons.repeat_one;
    }
  }

  void _showPlayerOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '播放器选项',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Consumer<MusicProvider>(
              builder: (context, musicProvider, child) {
                final currentSong = musicProvider.currentSong;
                if (currentSong == null) return const SizedBox.shrink();

                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.playlist_add),
                      title: const Text('添加到播放列表'),
                      onTap: () {
                        Navigator.pop(context);
                        _showPlaylistSelectionDialog(context, currentSong);
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('歌曲信息'),
                      onTap: () {
                        Navigator.pop(context);
                        _showSongInfo(context, currentSong);
                      },
                    ),
                    ListTile(
                      leading: Icon(musicProvider.shuffleMode
                          ? Icons.shuffle
                          : Icons.shuffle_outlined),
                      title:
                          Text(musicProvider.shuffleMode ? '关闭随机播放' : '开启随机播放'),
                      onTap: () {
                        musicProvider.toggleShuffle();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaylistSelectionDialog(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到播放列表'),
        content: Consumer<MusicProvider>(
          builder: (context, musicProvider, child) {
            if (musicProvider.playlists.isEmpty) {
              return const Text('暂无播放列表\n请先创建一个播放列表');
            }

            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: musicProvider.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = musicProvider.playlists[index];
                  return ListTile(
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songs.length} 首歌曲'),
                    onTap: () async {
                      await musicProvider.addSongToPlaylist(playlist.id, song);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已添加到 "${playlist.name}"'),
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                          ),
                        );
                      }
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歌曲信息'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('标题', song.title),
            _buildInfoRow('艺术家', song.artist),
            _buildInfoRow('专辑', song.album),
            _buildInfoRow('时长', _formatDuration(song.duration)),
            _buildInfoRow('文件路径', song.filePath),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}
