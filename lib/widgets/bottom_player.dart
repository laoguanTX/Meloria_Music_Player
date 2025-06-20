// ignore_for_file: deprecated_member_use

import 'dart:ui' as ui; // Added for lerpDouble
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../screens/player_screen.dart';
import 'dart:async';

class BottomPlayer extends StatefulWidget {
  // Changed to StatefulWidget
  const BottomPlayer({super.key});

  @override
  State<BottomPlayer> createState() => _BottomPlayerState();
}

class _BottomPlayerState extends State<BottomPlayer> with TickerProviderStateMixin {
  // Added TickerProviderStateMixin
  late AnimationController _progressAnimationController;
  late Animation<double> _curvedAnimation; // Added for smoother animation
  double _sliderDisplayValue = 0.0; // Value shown on the slider
  double _sliderTargetValue = 0.0; // Target value from MusicProvider
  double _animationStartValueForLerp = 0.0; // Start value for lerp interpolation
  bool _initialized = false; // To track if initial values have been set for the very first build
  Timer? _updateTimer;

  bool _isCurrentScreen = true; // Assume initially current, will be updated in didChangeDependencies
  bool _forceSnapOnNextBuild = false; // Flag to force snap when screen becomes current

  @override
  void initState() {
    super.initState();
    _progressAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300), // Adjusted animation duration
    )..addStatusListener(_handleAnimationStatus);

    _curvedAnimation = CurvedAnimation(parent: _progressAnimationController, curve: Curves.easeOut) // Added easing curve
      ..addListener(_handleAnimationTick);

    // 使用定时器定期更新进度，而不是依赖频繁的状态变化
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        final musicProvider = context.read<MusicProvider>();
        final newTargetValue = musicProvider.totalDuration.inMilliseconds > 0 ? musicProvider.currentPosition.inMilliseconds.toDouble() : 0.0;

        if (_sliderTargetValue != newTargetValue) {
          _sliderTargetValue = newTargetValue;
          if (!_progressAnimationController.isAnimating) {
            _animationStartValueForLerp = _sliderDisplayValue;
            _progressAnimationController.forward(from: 0.0);
          }
        }
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newIsCurrentScreen = ModalRoute.of(context)?.isCurrent ?? false;
    if (newIsCurrentScreen != _isCurrentScreen) {
      if (newIsCurrentScreen) {
        // Became the current screen (e.g., PlayerScreen was popped)
        // Set flag to snap the progress on the next build.
        // No need to call setState if build is already triggered by ModalRoute change.
        _forceSnapOnNextBuild = true;
      }
      _isCurrentScreen = newIsCurrentScreen;
    }
  }

  void _handleAnimationTick() {
    if (mounted) {
      setState(() {
        _sliderDisplayValue = ui.lerpDouble(_animationStartValueForLerp, _sliderTargetValue, _curvedAnimation.value)!; // Use curved animation
      });
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (mounted && _sliderDisplayValue != _sliderTargetValue) {
        // Ensure the display value exactly matches the target value upon completion.
        setState(() {
          _sliderDisplayValue = _sliderTargetValue;
        });
      }
    } else if (status == AnimationStatus.dismissed) {
      // Optional: Handle if animation is dismissed
      // This might be relevant if you implement features like reversing the animation
      // or if it's dismissed due to being stopped and reset.
      if (mounted && _sliderDisplayValue != _animationStartValueForLerp && _progressAnimationController.value == 0.0) {
        // If dismissed and not at the start (e.g., interrupted), consider snapping
        // to _animationStartValueForLerp or _sliderTargetValue based on desired behavior.
      }
    }
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

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
        double currentActualMillis = musicProvider.currentPosition.inMilliseconds.toDouble().clamp(0.0, totalMillis);

        // Always update the target for the animation/display
        _sliderTargetValue = currentActualMillis;

        if (!_isCurrentScreen) {
          // Not the current screen (e.g., PlayerScreen is active on top)
          // Keep the display value directly synced with the target, no animation.
          _sliderDisplayValue = _sliderTargetValue; // which is currentActualMillis
          _animationStartValueForLerp = _sliderTargetValue; // Keep lerp start synced too
          if (_progressAnimationController.isAnimating) {
            _progressAnimationController.stop(); // Stop any ongoing animation
          }
        } else {
          // This is the current screen
          if (!_initialized || _forceSnapOnNextBuild) {
            // First build ever, or just returned to this screen. Snap the value.
            _sliderDisplayValue = _sliderTargetValue; // Snap to currentActualMillis
            _animationStartValueForLerp = _sliderTargetValue;
            if (_progressAnimationController.isAnimating) {
              _progressAnimationController.stop();
            }
            if (_forceSnapOnNextBuild) {
              _forceSnapOnNextBuild = false; // Reset flag
            }
            if (!_initialized) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _initialized = true;
              });
            }
          } else {
            // Normal operation: current, initialized, not snapping. Animate if needed.
            if (_sliderDisplayValue != _sliderTargetValue) {
              if (!_progressAnimationController.isAnimating) {
                _animationStartValueForLerp = _sliderDisplayValue; // Start animation from current display
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _sliderDisplayValue != _sliderTargetValue) {
                    _progressAnimationController.forward(from: 0.0);
                  }
                });
              }
              // If animation is running, it will use the latest _sliderTargetValue due to lerp in tick.
            } else {
              // Display matches target, ensure animation is stopped if it was running and just completed.
              // The AnimationStatus.completed handler should manage this.
            }
          }
        }

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
                              if (musicProvider.totalDuration.inMilliseconds > 0) {
                                musicProvider.seekTo(Duration(milliseconds: value.toInt()));
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
