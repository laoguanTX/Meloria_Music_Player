// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import 'dart:typed_data'; // Ensure Uint8List is available
import '../widgets/music_waveform.dart'; // Added import

enum ArtistSortOrder {
  defaultAscending('默认排序 (原始顺序)'),
  defaultDescending('默认排序 (逆序)'),
  nameAscending('名称 (A-Z)'),
  nameDescending('名称 (Z-A)'),
  songCountAscending('歌曲数量 (少到多)'),
  songCountDescending('歌曲数量 (多到少)');

  const ArtistSortOrder(this.displayName);
  final String displayName;
}

class ArtistsScreen extends StatefulWidget {
  const ArtistsScreen({super.key});

  @override
  State<ArtistsScreen> createState() => _ArtistsScreenState();
}

class _ArtistsScreenState extends State<ArtistsScreen> {
  String? _selectedArtist;
  List<Song>? _selectedArtistSongs;
  ArtistSortOrder _currentSortOrder = ArtistSortOrder.defaultAscending; // 默认排序更改为 defaultAscending

  void _showSortOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.format_line_spacing_rounded),
                title: Text(ArtistSortOrder.defaultAscending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = ArtistSortOrder.defaultAscending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_line_spacing_rounded), // Consider a different icon for reverse
                title: Text(ArtistSortOrder.defaultDescending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = ArtistSortOrder.defaultDescending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: Text(ArtistSortOrder.nameAscending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = ArtistSortOrder.nameAscending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: Text(ArtistSortOrder.nameDescending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = ArtistSortOrder.nameDescending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered),
                title: Text(ArtistSortOrder.songCountAscending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = ArtistSortOrder.songCountAscending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered),
                title: Text(ArtistSortOrder.songCountDescending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = ArtistSortOrder.songCountDescending;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('音乐家'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序',
            onPressed: () {
              _showSortOptionsBottomSheet(context);
            },
          ),
          const SizedBox(width: 10), // 添加20px的空隙
        ],
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          List<String> artists = musicProvider.getUniqueArtists();

          // 应用排序
          switch (_currentSortOrder) {
            case ArtistSortOrder.defaultAscending:
              // 列表已经是原始顺序，无需操作
              break;
            case ArtistSortOrder.defaultDescending:
              artists = artists.reversed.toList();
              break;
            case ArtistSortOrder.nameAscending:
              artists.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              break;
            case ArtistSortOrder.nameDescending:
              artists.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
              break;
            case ArtistSortOrder.songCountAscending:
              artists.sort((a, b) {
                final countA = musicProvider.getSongsByArtist(a).length;
                final countB = musicProvider.getSongsByArtist(b).length;
                int comparison = countA.compareTo(countB);
                if (comparison == 0) {
                  // 如果歌曲数相同，则按名称排序
                  return a.toLowerCase().compareTo(b.toLowerCase());
                }
                return comparison;
              });
              break;
            case ArtistSortOrder.songCountDescending:
              artists.sort((a, b) {
                final countA = musicProvider.getSongsByArtist(a).length;
                final countB = musicProvider.getSongsByArtist(b).length;
                int comparison = countB.compareTo(countA);
                if (comparison == 0) {
                  // 如果歌曲数相同，则按名称排序
                  return a.toLowerCase().compareTo(b.toLowerCase());
                }
                return comparison;
              });
              break;
          }

          if (artists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_search_outlined, // Updated icon
                    size: 80,
                    color: colorScheme.primary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '暂无艺术家',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.85),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '你的音乐库中似乎还没有艺术家信息。\\n请先扫描或导入一些音乐。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          // 使用 AnimatedSwitcher 实现平滑过渡
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut, // 添加进入动画曲线
            switchOutCurve: Curves.easeInOut, // 添加退出动画曲线
            transitionBuilder: (Widget child, Animation<double> animation) {
              // 新视图从底部滑入，旧视图将执行此动画的反向操作（即滑出到底部）。
              // 由于 AnimatedSwitcher 的默认 layoutBuilder 将新视图叠放在旧视图之上，
              // 这会自然产生遮挡效果。
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.0, 1.0), // 从底部开始
                end: Offset.zero, // 在中心结束
              ).animate(animation);

              // 添加淡入淡出效果
              final fadeAnimation = Tween<double>(
                begin: 0.0, // 完全透明
                end: 1.0, // 完全不透明
              ).animate(animation);

              return FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: child,
                ),
              );
            },
            child: _selectedArtist == null
                ? ListView.builder(
                    key: const ValueKey<String>('artist_list_view_content'), // 为列表视图设置 Key
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), // Adjusted padding
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      final artistSongs = musicProvider.getSongsByArtist(artist);
                      final songCount = artistSongs.length;
                      final firstSong = artistSongs.isNotEmpty ? artistSongs.first : null;

                      return ArtistListTile(
                        artist: artist,
                        songCount: songCount,
                        albumArt: firstSong?.albumArt,
                        onTap: () {
                          setState(() {
                            _selectedArtist = artist;
                            _selectedArtistSongs = artistSongs;
                          });
                        },
                      );
                    },
                  )
                : Row(
                    key: ValueKey<String?>(_selectedArtist), // 为详情视图设置 Key，依赖于选中的艺术家
                    children: [
                      // 左侧：艺术家列表
                      Expanded(
                        flex: 1, // Adjust flex factor as needed, e.g. 2 for wider list
                        child: Column(
                          children: [
                            // 返回按钮和标题
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedArtist = null;
                                        _selectedArtistSongs = null;
                                      });
                                    },
                                    tooltip: '返回艺术家列表',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  Expanded(
                                    child: Text(
                                      '音乐家',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 48), // 占位，保持标题居中
                                ],
                              ),
                            ),
                            // 艺术家列表
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                itemCount: artists.length,
                                itemBuilder: (context, index) {
                                  final artist = artists[index];
                                  final artistSongs = musicProvider.getSongsByArtist(artist);
                                  final songCount = artistSongs.length;
                                  final firstSong = artistSongs.isNotEmpty ? artistSongs.first : null;
                                  final isSelected = artist == _selectedArtist;

                                  return ArtistListTile(
                                    artist: artist,
                                    songCount: songCount,
                                    albumArt: firstSong?.albumArt,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        _selectedArtist = artist;
                                        _selectedArtistSongs = artistSongs;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 右侧：艺术家详情
                      Expanded(
                        flex: 3, // Adjust flex factor, e.g. 5 for wider detail
                        child: ArtistDetailView(
                          artist: _selectedArtist!,
                          songs: _selectedArtistSongs!,
                          musicProvider: musicProvider, // Pass musicProvider
                        ),
                      ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class ArtistListTile extends StatelessWidget {
  final String artist;
  final int songCount;
  final Uint8List? albumArt;
  final VoidCallback onTap;
  final bool isSelected;

  const ArtistListTile({
    super.key,
    required this.artist,
    required this.songCount,
    this.albumArt,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      // elevation: isSelected ? 2.5 : 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isSelected ? colorScheme.primary.withOpacity(0.7) : Colors.transparent,
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      color: isSelected ? colorScheme.primaryContainer.withOpacity(0.4) : null,
      clipBehavior: Clip.antiAlias, // Ensures InkWell ripple is contained
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: colorScheme.surfaceContainerHighest, // Placeholder background
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: albumArt != null && albumArt!.isNotEmpty
                      ? Image.memory(
                          albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person_outline_rounded,
                              size: 28,
                              color: colorScheme.onSurfaceVariant,
                            );
                          },
                        )
                      : Icon(
                          Icons.person_outline_rounded,
                          size: 28,
                          color: colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      artist.isNotEmpty ? artist : '未知艺术家',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? colorScheme.primary : colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (songCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: Text(
                          '$songCount 首歌曲',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isSelected ? colorScheme.primary.withOpacity(0.85) : colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(0.7),
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtistDetailView extends StatelessWidget {
  final String artist;
  final List<Song> songs;
  final MusicProvider musicProvider; // Added to access playSong

  const ArtistDetailView({
    super.key,
    required this.artist,
    required this.songs,
    required this.musicProvider,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Duration totalDuration = Duration.zero;
    for (var song in songs) {
      totalDuration += song.duration;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 艺术家信息头部
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(40),
                  child: songs.isNotEmpty && songs.first.albumArt != null && songs.first.albumArt!.isNotEmpty
                      ? Image.memory(
                          songs.first.albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: colorScheme.surfaceVariant,
                              child: Icon(
                                Icons.person_outline_rounded,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: colorScheme.surfaceVariant,
                          child: Icon(
                            Icons.person_outline_rounded,
                            size: 40,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      artist.isNotEmpty ? artist : '未知艺术家',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${songs.length} 首歌曲 • ${_formatDuration(totalDuration)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (songs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_circle_fill_rounded),
                  iconSize: 52,
                  color: colorScheme.primary,
                  onPressed: () {
                    musicProvider.playSong(songs.first, index: 0);
                  },
                  tooltip: '播放该艺术家的全部歌曲',
                ),
            ],
          ),
        ),
        // const Divider(height: 1, indent: 16, endIndent: 16),
        // 歌曲列表
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return ArtistSongTile(
                song: song,
                index: index,
                onTap: () {
                  musicProvider.playSong(song, index: index);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// This screen seems to be a separate, full-screen detail view.
// It's not directly part of the main ArtistsScreen flow with split view.
// Keeping it as is unless specific changes are requested for it.
class ArtistDetailScreen extends StatelessWidget {
  final String artist;
  final List<Song> songs;

  const ArtistDetailScreen({
    super.key,
    required this.artist,
    required this.songs,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 计算总时长
    Duration totalDuration = Duration.zero;
    for (var song in songs) {
      totalDuration += song.duration;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(artist.isNotEmpty ? artist : '未知艺术家'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            onPressed: () {
              if (songs.isNotEmpty) {
                final musicProvider = context.read<MusicProvider>();
                musicProvider.playSong(songs.first, index: 0);
              }
            },
            tooltip: '播放全部',
          ),
        ],
      ),
      body: Column(
        children: [
          // 艺术家信息头部
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    color: theme.colorScheme.primaryContainer,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: songs.isNotEmpty && songs.first.albumArt != null
                        ? Image.memory(
                            songs.first.albumArt!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 60,
                                color: theme.colorScheme.onPrimaryContainer,
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            size: 60,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  artist.isNotEmpty ? artist : '未知艺术家',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '${songs.length} 首歌曲 • ${_formatDuration(totalDuration)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // 歌曲列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ArtistSongTile(
                  // Uses the beautified ArtistSongTile
                  song: song,
                  index: index,
                  onTap: () {
                    final musicProvider = context.read<MusicProvider>();
                    musicProvider.playSong(song, index: index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ArtistSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const ArtistSongTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final isCurrentSong = musicProvider.currentSong?.id == song.id;
        final isPlaying = musicProvider.isPlaying;

        return Card(
          // elevation: isCurrentSong ? 1.0 : 0.2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
            // side: BorderSide( // This was from a different widget, removed for consistency with original ArtistSongTile
            //   color: isCurrentSong ? colorScheme.primary.withOpacity(0.7) : Colors.transparent,
            //   width: 1.5,
            // ),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
          color: isCurrentSong ? colorScheme.primaryContainer.withOpacity(0.3) : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10.0), // Match Card's border radius
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Center(
                      child: isCurrentSong
                          ? (isPlaying
                              ? MusicWaveform(color: colorScheme.primary, size: 26.0)
                              : Icon(Icons.pause, color: colorScheme.primary, size: 26.0))
                          : Text(
                              '${index + 1}',
                              style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          song.title.isNotEmpty ? song.title : "未知歌曲",
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentSong ? colorScheme.primary : colorScheme.onSurface,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (song.album.isNotEmpty && song.album != 'Unknown Album')
                          Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text(
                              song.album,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isCurrentSong ? colorScheme.primary.withOpacity(0.8) : colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _formatDuration(song.duration),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCurrentSong ? colorScheme.primary.withOpacity(0.9) : colorScheme.onSurfaceVariant.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
