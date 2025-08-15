// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import 'dart:typed_data';
import '../widgets/music_waveform.dart';

enum AlbumSortOrder {
  defaultAscending('默认排序 (原始顺序)'),
  defaultDescending('默认排序 (逆序)'),
  nameAscending('名称 (A-Z)'),
  nameDescending('名称 (Z-A)'),
  songCountAscending('歌曲数量 (少到多)'),
  songCountDescending('歌曲数量 (多到少)');

  const AlbumSortOrder(this.displayName);
  final String displayName;
}

class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

class _AlbumsScreenState extends State<AlbumsScreen> {
  String? _selectedAlbum;
  List<Song>? _selectedAlbumSongs;
  AlbumSortOrder _currentSortOrder = AlbumSortOrder.defaultAscending;

  void _showSortOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.format_line_spacing_rounded),
                title: Text(AlbumSortOrder.defaultAscending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = AlbumSortOrder.defaultAscending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_line_spacing_rounded),
                title: Text(AlbumSortOrder.defaultDescending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = AlbumSortOrder.defaultDescending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: Text(AlbumSortOrder.nameAscending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = AlbumSortOrder.nameAscending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sort_by_alpha),
                title: Text(AlbumSortOrder.nameDescending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = AlbumSortOrder.nameDescending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered),
                title: Text(AlbumSortOrder.songCountAscending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = AlbumSortOrder.songCountAscending;
                  });
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_list_numbered),
                title: Text(AlbumSortOrder.songCountDescending.displayName),
                onTap: () {
                  setState(() {
                    _currentSortOrder = AlbumSortOrder.songCountDescending;
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
        title: const Text('专辑'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: '排序方式',
            onPressed: () {
              _showSortOptionsBottomSheet(context);
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          List<String> albums = musicProvider.getUniqueAlbums();

          switch (_currentSortOrder) {
            case AlbumSortOrder.defaultAscending:
              break;
            case AlbumSortOrder.defaultDescending:
              albums = albums.reversed.toList();
              break;
            case AlbumSortOrder.nameAscending:
              albums.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              break;
            case AlbumSortOrder.nameDescending:
              albums.sort((a, b) => b.toLowerCase().compareTo(a.toLowerCase()));
              break;
            case AlbumSortOrder.songCountAscending:
              albums.sort((a, b) {
                final countA = musicProvider.getSongsByAlbum(a).length;
                final countB = musicProvider.getSongsByAlbum(b).length;
                int comparison = countA.compareTo(countB);
                if (comparison == 0) {
                  return a.toLowerCase().compareTo(b.toLowerCase());
                }
                return comparison;
              });
              break;
            case AlbumSortOrder.songCountDescending:
              albums.sort((a, b) {
                final countA = musicProvider.getSongsByAlbum(a).length;
                final countB = musicProvider.getSongsByAlbum(b).length;
                int comparison = countB.compareTo(countA);
                if (comparison == 0) {
                  return a.toLowerCase().compareTo(b.toLowerCase());
                }
                return comparison;
              });
              break;
          }

          if (albums.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.album_outlined,
                    size: 80,
                    color: colorScheme.primary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '暂无专辑',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.85),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '你的音乐库中似乎还没有专辑信息。\n请先扫描或导入一些音乐。',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            );
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(animation);

              final fadeAnimation = Tween<double>(
                begin: 0.0,
                end: 1.0,
              ).animate(animation);

              return FadeTransition(
                opacity: fadeAnimation,
                child: SlideTransition(
                  position: slideAnimation,
                  child: child,
                ),
              );
            },
            child: _selectedAlbum == null
                ? ListView.builder(
                    key: const ValueKey<String>('album_list_view_content'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      final album = albums[index];
                      final albumSongs = musicProvider.getSongsByAlbum(album);
                      final songCount = albumSongs.length;
                      final firstSong = albumSongs.isNotEmpty ? albumSongs.first : null;

                      return AlbumListTile(
                        album: album,
                        songCount: songCount,
                        albumArt: firstSong?.albumArt,
                        onTap: () {
                          setState(() {
                            _selectedAlbum = album;
                            _selectedAlbumSongs = albumSongs;
                          });
                        },
                      );
                    },
                  )
                : Row(
                    key: ValueKey<String?>(_selectedAlbum),
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedAlbum = null;
                                        _selectedAlbumSongs = null;
                                      });
                                    },
                                    tooltip: '返回专辑列表',
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  Expanded(
                                    child: Text(
                                      '专辑',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const SizedBox(width: 48),
                                ],
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                itemCount: albums.length,
                                itemBuilder: (context, index) {
                                  final album = albums[index];
                                  final albumSongs = musicProvider.getSongsByAlbum(album);
                                  final songCount = albumSongs.length;
                                  final firstSong = albumSongs.isNotEmpty ? albumSongs.first : null;
                                  final isSelected = album == _selectedAlbum;

                                  return AlbumListTile(
                                    album: album,
                                    songCount: songCount,
                                    albumArt: firstSong?.albumArt,
                                    isSelected: isSelected,
                                    onTap: () {
                                      setState(() {
                                        _selectedAlbum = album;
                                        _selectedAlbumSongs = albumSongs;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: AlbumDetailView(
                          album: _selectedAlbum!,
                          songs: _selectedAlbumSongs!,
                          musicProvider: musicProvider,
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

class AlbumListTile extends StatelessWidget {
  final String album;
  final int songCount;
  final Uint8List? albumArt;
  final VoidCallback onTap;
  final bool isSelected;

  const AlbumListTile({
    super.key,
    required this.album,
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
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isSelected ? colorScheme.primary.withOpacity(0.7) : Colors.transparent,
          width: 1.5,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 8.0),
      color: isSelected ? colorScheme.primaryContainer.withOpacity(0.4) : null,
      clipBehavior: Clip.antiAlias,
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
                  borderRadius: BorderRadius.circular(8),
                  color: colorScheme.surfaceContainerHighest,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: albumArt != null && albumArt!.isNotEmpty
                      ? Image.memory(
                          albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.album_outlined,
                              size: 28,
                              color: colorScheme.onSurfaceVariant,
                            );
                          },
                        )
                      : Icon(
                          Icons.album_outlined,
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
                      album.isNotEmpty ? album : '未知专辑',
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

class AlbumDetailView extends StatelessWidget {
  final String album;
  final List<Song> songs;
  final MusicProvider musicProvider;

  const AlbumDetailView({
    super.key,
    required this.album,
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
    final String albumArtist = songs.isNotEmpty && songs.first.artist.isNotEmpty ? songs.first.artist : "多个艺术家";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: theme.shadowColor.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: songs.isNotEmpty && songs.first.albumArt != null && songs.first.albumArt!.isNotEmpty
                      ? Image.memory(
                          songs.first.albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: colorScheme.surfaceVariant,
                              child: Icon(
                                Icons.album_outlined,
                                size: 40,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.album_outlined,
                          size: 40,
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
                      album.isNotEmpty ? album : '未知专辑',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      albumArtist,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 1,
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
                    musicProvider.playAllByAlbum(album, albumArtist);
                  },
                  tooltip: '播放该专辑的全部歌曲',
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: songs.length,
            itemBuilder: (context, index) {
              final song = songs[index];
              return AlbumSongTile(
                // Changed from ArtistSongTile
                song: song,
                index: index,
                onTap: () {
                  if (musicProvider.repeatMode.toString() == 'RepeatMode.playlistLoop') {
                    musicProvider.playSong(song);
                  } else {
                    musicProvider.playSong(song, index: index);
                  }
                },
                albumSongsList: songs, // Ensure this is passed
              );
            },
          ),
        ),
      ],
    );
  }
}

class AlbumDetailScreen extends StatelessWidget {
  final String album;
  final List<Song> songs;

  const AlbumDetailScreen({
    super.key,
    required this.album,
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
    final String albumArtist = songs.isNotEmpty && songs.first.artist.isNotEmpty ? songs.first.artist : "多个艺术家";

    Duration totalDuration = Duration.zero;
    for (var song in songs) {
      totalDuration += song.duration;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(album.isNotEmpty ? album : '未知专辑'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.play_circle_filled),
            onPressed: () {
              if (songs.isNotEmpty) {
                final musicProvider = context.read<MusicProvider>();
                musicProvider.playAllByAlbum(album, albumArtist);
              }
            },
            tooltip: '播放全部',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
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
                    borderRadius: BorderRadius.circular(12),
                    child: songs.isNotEmpty && songs.first.albumArt != null
                        ? Image.memory(
                            songs.first.albumArt!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.album_outlined, // Changed icon
                                size: 60,
                                color: theme.colorScheme.onPrimaryContainer,
                              );
                            },
                          )
                        : Icon(
                            Icons.album_outlined,
                            size: 60,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  album.isNotEmpty ? album : '未知专辑',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  albumArtist,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.normal,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return AlbumSongTile(
                  song: song,
                  index: index,
                  onTap: () {
                    final musicProvider = context.read<MusicProvider>();
                    if (musicProvider.repeatMode.toString() == 'RepeatMode.playlistLoop') {
                      musicProvider.playSong(song);
                    } else {
                      musicProvider.playSong(song, index: index);
                    }
                  },
                  albumSongsList: songs,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AlbumSongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final List<Song> albumSongsList;
  const AlbumSongTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    required this.albumSongsList,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
          color: isCurrentSong ? colorScheme.primaryContainer.withOpacity(0.3) : null,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10.0),
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
                        if (song.artist.isNotEmpty &&
                            song.artist != "多个艺术家" &&
                            (albumSongsList.isEmpty || song.artist != albumSongsList.first.artist))
                          Padding(
                            padding: const EdgeInsets.only(top: 3.0),
                            child: Text(
                              song.artist,
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
