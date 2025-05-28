// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui; // Added for lerpDouble
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';

class BottomPlayer extends StatefulWidget {
  // Changed to StatefulWidget
  const BottomPlayer({super.key});

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer>
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final song = musicProvider.currentSong;
        if (song == null) return const SizedBox.shrink();

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

        // Update target value and start animation if needed
        if (_sliderTargetValue != currentActualMillis) {
          if (_progressAnimationController.isAnimating) {
            _progressAnimationController
                .stop(); // Stop current animation before starting a new one
          }
          _animationStartValueForLerp =
              _sliderDisplayValue; // Current display value is the start for lerp
          _sliderTargetValue = currentActualMillis; // New target from provider
          _progressAnimationController.forward(
              from: 0.0); // Start animation from beginning
        } else if (!_progressAnimationController.isAnimating &&
            _sliderDisplayValue != _sliderTargetValue) {
          // If not animating but display is not at target (e.g. after user drag or initial load)
          // Snap to the target value
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
          margin: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 8,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlayerScreen(),
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
                            value: _sliderDisplayValue.clamp(0.0, totalMillis),
                            min: 0.0,
                            max: totalMillis,
                            onChanged: (value) {
                              // Stop animation if it's running
                              if (_progressAnimationController.isAnimating) {
                                _progressAnimationController.stop();
                              }
                              // Update display value immediately for responsiveness
                              if (mounted) {
                                setState(() {
                                  _sliderDisplayValue = value;
                                });
                              }
                              // Seek to the new position
                              if (musicProvider.totalDuration.inMilliseconds >
                                  0) {
                                musicProvider.seekTo(
                                    Duration(milliseconds: value.toInt()));
                              }
                              // Update the target value to prevent animation jump after user releases slider
                              _sliderTargetValue = value;
                            },
                            onChangeStart: (_) {
                              // When user starts dragging
                              if (_progressAnimationController.isAnimating) {
                                _progressAnimationController.stop();
                              }
                              // Update the animation start value to the current display value
                              _animationStartValueForLerp = _sliderDisplayValue;
                            },
                            onChangeEnd: (value) {
                              // Optional: Actions when dragging ends.
                              // The existing logic should handle animation based on musicProvider updates.
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            inactiveColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
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
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: song.albumArt != null
                                ? AspectRatio(
                                    aspectRatio: 1.0, // 强制正方形比例
                                    child: Image.memory(
                                      song.albumArt!,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Icon(
                                          Icons.music_note,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimaryContainer,
                                        );
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.music_note,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
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
                              width: 150, // 设置固定宽度，作为“长度减半”的近似实现
                              child: Slider(
                                value: musicProvider.volume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (value) {
                                  musicProvider.setVolume(value);
                                },
                                activeColor:
                                    Theme.of(context).colorScheme.primary,
                                inactiveColor: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.3),
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
                            musicProvider.isPlaying
                                ? Icons.pause_circle_filled
                                : Icons.play_circle_filled,
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
