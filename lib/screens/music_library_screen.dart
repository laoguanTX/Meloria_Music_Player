// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';
import '../widgets/music_waveform.dart';

class MusicLibrary extends StatefulWidget {
  const MusicLibrary({super.key});

  @override
  State<MusicLibrary> createState() => _MusicLibraryState();
}

class _MusicLibraryState extends State<MusicLibrary> {
  bool _isSelectionMode = false;
  final Set<String> _selectedSongs = <String>{};

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedSongs.clear();
    });
  }

  void _toggleViewMode() {
    context.read<MusicProvider>().toggleViewMode();
  }

  void _toggleSongSelection(String songId) {
    setState(() {
      if (_selectedSongs.contains(songId)) {
        _selectedSongs.remove(songId);
      } else {
        _selectedSongs.add(songId);
      }
    });
  }

  void _selectAll(List<Song> songs) {
    setState(() {
      _selectedSongs.clear();
      _selectedSongs.addAll(songs.map((song) => song.id));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedSongs.clear();
    });
  }

  Future<void> _deleteSelectedSongs() async {
    if (_selectedSongs.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除选中的歌曲'),
        content: Text('确定要删除选中的 ${_selectedSongs.length} 首歌曲吗？\n\n注意：这只会从音乐库中移除，不会删除原文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      final success = await context.read<MusicProvider>().deleteSongs(_selectedSongs.toList());
      if (!mounted) return;
      Navigator.pop(context);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 ${_selectedSongs.length} 首歌曲'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        _toggleSelectionMode();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('删除歌曲失败'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '排序方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.title),
              title: const Text('按标题排序'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('title');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('按艺术家排序'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('artist');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.album),
              title: const Text('按专辑排序'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('album');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.access_time),
              title: const Text('按时长排序'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('duration');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.new_releases_outlined),
              title: const Text('按添加时间'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('date');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('按文件创建日期'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('createdDate');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('按文件修改日期'),
              onTap: () {
                context.read<MusicProvider>().sortSongs('modifiedDate');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditSongInfo(BuildContext context, Song song) {
    final TextEditingController titleController = TextEditingController(text: song.title);
    final TextEditingController artistController = TextEditingController(text: song.artist);
    final TextEditingController albumController = TextEditingController(text: song.album);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑歌曲信息'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: '标题',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: artistController,
                decoration: const InputDecoration(
                  labelText: '艺术家',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: albumController,
                decoration: const InputDecoration(
                  labelText: '专辑',
                  border: OutlineInputBorder(),
                ),
                maxLines: 1,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              final updatedSong = Song(
                id: song.id,
                title: titleController.text.trim().isEmpty ? song.title : titleController.text.trim(),
                artist: artistController.text.trim().isEmpty ? song.artist : artistController.text.trim(),
                album: albumController.text.trim().isEmpty ? song.album : albumController.text.trim(),
                filePath: song.filePath,
                duration: song.duration,
                albumArt: song.albumArt,
                playCount: song.playCount,
                hasLyrics: song.hasLyrics,
                embeddedLyrics: song.embeddedLyrics,
                createdDate: song.createdDate,
                modifiedDate: song.modifiedDate,
              );

              final success = await context.read<MusicProvider>().updateSongInfo(updatedSong);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('歌曲信息已更新'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('更新歌曲信息失败'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showPlaylistSelectionDialog(BuildContext context, Song song) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final playlists = musicProvider.playlists;

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('添加到歌单'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('没有可用的歌单。'),
                  ),
                SizedBox(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist.name),
                        onTap: () async {
                          try {
                            await musicProvider.addSongsToPlaylist(playlist.id, [song.id]);
                            Navigator.of(dialogContext).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已将 "${song.title}" 添加到 "${playlist.name}"')),
                            );
                          } catch (e) {
                            Navigator.of(dialogContext).pop(); // Close dialog
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('添加到歌单失败: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('创建新歌单...'),
                  onTap: () async {
                    Navigator.of(dialogContext).pop(); // Close this dialog first
                    _showCreatePlaylistAndAddSongDialog(context, song);
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistAndAddSongDialog(BuildContext context, Song song) {
    final TextEditingController playlistNameController = TextEditingController();
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('创建新歌单并添加歌曲'),
          content: TextField(
            controller: playlistNameController,
            decoration: InputDecoration(hintText: '歌单名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('创建并添加'),
              onPressed: () async {
                final String name = playlistNameController.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await musicProvider.createPlaylist(name);
                    dynamic newPlaylist;
                    for (var p in musicProvider.playlists) {
                      if (p.name == name) {
                        newPlaylist = p;
                        break;
                      }
                    }

                    if (newPlaylist != null) {
                      await musicProvider.addSongsToPlaylist(newPlaylist.id, [song.id]);
                      Navigator.of(dialogContext).pop(); // Close create dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已将 "${song.title}" 添加到新歌单 "${newPlaylist.name}"')),
                      );
                    } else {
                      Navigator.of(dialogContext).pop(); // Close create dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('创建播放列表后未能找到它。请确保名称唯一。')),
                      );
                    }
                  } catch (e) {
                    Navigator.of(dialogContext).pop(); // Close create dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建或添加歌曲失败: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    ).then((_) => playlistNameController.dispose());
  }

  void _showPlaylistSelectionDialogForMultiple(BuildContext context, List<Song> songs) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final playlists = musicProvider.playlists;

    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('添加到歌单'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (playlists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Text('没有可用的歌单。'),
                  ),
                SizedBox(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return ListTile(
                        title: Text(playlist.name),
                        onTap: () async {
                          try {
                            await musicProvider.addSongsToPlaylist(
                              playlist.id,
                              songs.map((s) => s.id).toList(),
                            );
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已将 ${songs.length} 首歌曲添加到 "${playlist.name}"')),
                            );
                            _toggleSelectionMode();
                          } catch (e) {
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('添加到歌单失败: $e')),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.add_circle_outline),
                  title: Text('创建新歌单...'),
                  onTap: () async {
                    Navigator.of(dialogContext).pop();
                    _showCreatePlaylistAndAddMultipleSongsDialog(context, songs);
                  },
                )
              ],
            ),
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showCreatePlaylistAndAddMultipleSongsDialog(BuildContext context, List<Song> songs) {
    final TextEditingController playlistNameController = TextEditingController();
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('创建新歌单并添加歌曲'),
          content: TextField(
            controller: playlistNameController,
            decoration: InputDecoration(hintText: '歌单名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              child: Text('取消'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: Text('创建并添加'),
              onPressed: () async {
                final String name = playlistNameController.text.trim();
                if (name.isNotEmpty) {
                  try {
                    await musicProvider.createPlaylist(name);
                    dynamic newPlaylist;
                    for (var p in musicProvider.playlists) {
                      if (p.name == name) {
                        newPlaylist = p;
                        break;
                      }
                    }
                    if (newPlaylist != null) {
                      await musicProvider.addSongsToPlaylist(
                        newPlaylist.id,
                        songs.map((s) => s.id).toList(),
                      );
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已将 ${songs.length} 首歌曲添加到新歌单 "${newPlaylist.name}"')),
                      );
                      _toggleSelectionMode();
                    } else {
                      Navigator.of(dialogContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('创建播放列表后未能找到它。请确保名称唯一。')),
                      );
                    }
                  } catch (e) {
                    Navigator.of(dialogContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('创建或添加歌曲失败: $e')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    ).then((_) => playlistNameController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    Widget? leadingWidget;
    if (_isSelectionMode) {
      leadingWidget = IconButton(
        icon: const Icon(Icons.close),
        onPressed: _toggleSelectionMode,
      );
    } else {
      leadingWidget = Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          return Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: ElevatedButton.icon(
              onPressed: musicProvider.songs.isEmpty
                  ? null
                  : () {
                      musicProvider.playAllSongs();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已将 ${musicProvider.songs.length} 首歌曲添加到播放队列')),
                      );
                    },
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('播放全部'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8), // Adjust padding if needed
              ),
            ),
          );
        },
      );
    }

    Widget titleWidget = _isSelectionMode ? Text('已选择 ${_selectedSongs.length} 首') : const Text('音乐库');

    List<Widget> actionsWidgets = [];
    if (_isSelectionMode) {
      if (_selectedSongs.isEmpty) {
        actionsWidgets.add(Consumer<MusicProvider>(
          builder: (context, musicProvider, child) {
            return IconButton(
              icon: const Icon(Icons.select_all),
              onPressed: () => _selectAll(musicProvider.songs),
              tooltip: '全选',
            );
          },
        ));
      } else {
        actionsWidgets.add(IconButton(
          icon: const Icon(Icons.deselect),
          onPressed: _deselectAll,
          tooltip: '取消全选',
        ));
        actionsWidgets.add(IconButton(
          icon: const Icon(Icons.queue_music),
          onPressed: () {
            final musicProvider = context.read<MusicProvider>();
            final selectedSongs = musicProvider.songs.where((s) => _selectedSongs.contains(s.id)).toList();
            if (selectedSongs.isNotEmpty) {
              musicProvider.addMultipleToPlayQueue(selectedSongs);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已将 ${selectedSongs.length} 首歌曲添加到播放队列'),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                ),
              );
              _toggleSelectionMode();
            }
          },
          tooltip: '添加到播放队列',
        ));
        actionsWidgets.add(IconButton(
          icon: const Icon(Icons.playlist_add),
          onPressed: () {
            final musicProvider = context.read<MusicProvider>();
            final selectedSongs = musicProvider.songs.where((s) => _selectedSongs.contains(s.id)).toList();
            if (selectedSongs.isNotEmpty) {
              _showPlaylistSelectionDialogForMultiple(context, selectedSongs);
            }
          },
          tooltip: '添加到歌单',
        ));
      }
      actionsWidgets.add(IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: _selectedSongs.isNotEmpty ? _deleteSelectedSongs : null,
        tooltip: '删除选中',
      ));
    } else {
      actionsWidgets.add(Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: ElevatedButton.icon(
          onPressed: () {
            context.read<MusicProvider>().importMusic();
          },
          icon: const Icon(Icons.add, size: 18),
          label: const Text('导入音乐'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8), // Adjust padding if needed
          ),
        ),
      ));
      actionsWidgets.add(Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          return IconButton(
            icon: Icon(musicProvider.isGridView ? Icons.view_list : Icons.grid_view),
            onPressed: _toggleViewMode,
            tooltip: musicProvider.isGridView ? '列表视图' : '网格视图',
          );
        },
      ));
      actionsWidgets.add(IconButton(
        icon: const Icon(Icons.checklist),
        onPressed: _toggleSelectionMode,
        tooltip: '批量选择',
      ));
      actionsWidgets.add(IconButton(
        icon: const Icon(Icons.sort),
        onPressed: () {
          _showSortOptions(context);
        },
        tooltip: '排序',
      ));
      actionsWidgets.add(Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          return IconButton(
            icon: Icon(musicProvider.sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              musicProvider.toggleSortDirection();
            },
            tooltip: musicProvider.sortAscending ? '升序' : '降序',
          );
        },
      ));
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight), // Standard AppBar height
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0), // Added 20px top padding, maintained 20px horizontal padding
          color: Colors.transparent, // As per original AppBar's backgroundColor
          child: Builder(builder: (context) {
            // Builder to get context for theme
            final ThemeData theme = Theme.of(context);
            final AppBarTheme appBarTheme = AppBarTheme.of(context);
            // Mimic AppBar's title text style resolution
            final TextStyle? titleStyle = appBarTheme.titleTextStyle ?? theme.primaryTextTheme.titleLarge ?? theme.textTheme.titleLarge;

            return NavigationToolbar(
              leading: leadingWidget,
              middle: DefaultTextStyle(
                style: titleStyle ?? TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface), // Fallback style
                child: titleWidget,
              ),
              trailing: actionsWidgets.isNotEmpty ? Row(mainAxisSize: MainAxisSize.min, children: actionsWidgets) : null,
              centerMiddle: true, // Common default; AppBar's centerTitle is platform/theme dependent
              middleSpacing: NavigationToolbar.kMiddleSpacing, // Standard spacing around the middle widget
            );
          }),
        ),
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          if (musicProvider.songs.isEmpty) {
            return const EmptyLibraryWidget();
          }
          return Column(
            children: [
              Expanded(
                child: Consumer<MusicProvider>(
                  builder: (context, musicProvider, child) {
                    return musicProvider.isGridView
                        ? GridView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 0.78,
                            ),
                            itemCount: musicProvider.songs.length,
                            itemBuilder: (context, index) {
                              final song = musicProvider.songs[index];
                              return SongGridItem(
                                song: song,
                                index: index,
                                isSelectionMode: _isSelectionMode,
                                isSelected: _selectedSongs.contains(song.id),
                                onTap: _isSelectionMode ? () => _toggleSongSelection(song.id) : () => musicProvider.playSong(song, index: index),
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode();
                                    _toggleSongSelection(song.id);
                                  }
                                },
                              );
                            },
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: musicProvider.songs.length,
                            itemBuilder: (context, index) {
                              final song = musicProvider.songs[index];
                              return SongListTile(
                                song: song,
                                index: index,
                                isSelectionMode: _isSelectionMode,
                                isSelected: _selectedSongs.contains(song.id),
                                onTap: _isSelectionMode ? () => _toggleSongSelection(song.id) : () => musicProvider.playSong(song, index: index),
                                onLongPress: () {
                                  if (!_isSelectionMode) {
                                    _toggleSelectionMode();
                                    _toggleSongSelection(song.id);
                                  }
                                },
                              );
                            },
                          );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class EmptyLibraryWidget extends StatelessWidget {
  const EmptyLibraryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.library_music_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '音乐库为空',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮导入您的音乐',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              context.read<MusicProvider>().importMusic();
            },
            icon: const Icon(Icons.add),
            label: const Text('导入音乐'),
          ),
        ],
      ),
    );
  }
}

class SongListTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isSelectionMode;
  final bool isSelected;

  const SongListTile({
    super.key,
    required this.song,
    required this.index,
    required this.onTap,
    this.onLongPress,
    this.isSelectionMode = false,
    this.isSelected = false,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  List<PopupMenuEntry<String>> _getPopupMenuItems(BuildContext context) {
    return [
      const PopupMenuItem(
        value: 'add_to_queue',
        child: Row(
          children: [
            Icon(Icons.queue_music),
            SizedBox(width: 8),
            Text('添加到播放队列'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'add_to_playlist', // Added value
        child: Row(
          children: [
            Icon(Icons.playlist_add),
            SizedBox(width: 8),
            Text('添加到歌单'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'song_info',
        child: Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Text('歌曲信息'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'edit_info',
        child: Row(
          children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('编辑信息'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline),
            SizedBox(width: 8),
            Text('删除'),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final isCurrentSong = musicProvider.currentSong?.id == song.id;

        return GestureDetector(
            onSecondaryTapUp: (TapUpDetails details) {
              if (!isSelectionMode) {
                final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
                final RelativeRect position = RelativeRect.fromRect(
                  Rect.fromPoints(
                    details.globalPosition,
                    details.globalPosition,
                  ),
                  Offset.zero & overlay.size,
                );

                showMenu<String>(
                  context: context,
                  position: position,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  items: _getPopupMenuItems(context),
                ).then((String? value) {
                  if (value != null) {
                    _handleMenuAction(context, value, song);
                  }
                });
              }
            },
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
                side: isCurrentSong ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
              ),
              clipBehavior: Clip.antiAlias,
              color: isCurrentSong
                  ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4)
                  : isSelected
                      ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
                      : null,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                contentPadding: const EdgeInsets.all(12),
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelectionMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (_) => onTap(),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12.0),
                          color: song.albumArt == null
                              ? (isCurrentSong ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.primaryContainer)
                              : null,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: song.albumArt != null
                              ? Stack(
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 1.0,
                                      child: Image.memory(
                                        song.albumArt!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return _buildDefaultIcon(context, isCurrentSong, musicProvider);
                                        },
                                      ),
                                    ),
                                    if (isCurrentSong && musicProvider.isPlaying)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          child: const MusicWaveform(
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                    if (isCurrentSong && !musicProvider.isPlaying && song.albumArt != null)
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                                            borderRadius: BorderRadius.circular(12.0),
                                          ),
                                          child: const Icon(
                                            Icons.pause, // Pause icon
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : _buildDefaultIcon(context, isCurrentSong, musicProvider),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        song.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isCurrentSong ? Theme.of(context).colorScheme.primary : null,
                              fontWeight: isCurrentSong ? FontWeight.bold : null,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (song.filePath.toLowerCase().endsWith('.flac'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.amber, width: 1),
                            ),
                            child: Text(
                              'FLAC',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.amber.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        if (song.filePath.toLowerCase().endsWith('.wav'))
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.green, width: 1),
                            ),
                            child: Text(
                              'WAV',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                subtitle: Row(
                  // Changed to Row
                  crossAxisAlignment: CrossAxisAlignment.end, // Vertically align items
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.artist,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (song.album.isNotEmpty && song.album != 'Unknown Album')
                            Text(
                              song.album,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8), // Spacer
                    Text(
                      _formatDuration(song.duration),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            // Increased font size
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
                trailing: isSelectionMode
                    ? null
                    : PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        tooltip: '更多',
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        onSelected: (value) {
                          _handleMenuAction(context, value, song);
                        },
                        itemBuilder: (context) => _getPopupMenuItems(context),
                      ),
                onTap: onTap,
                onLongPress: onLongPress,
              ),
            ));
      },
    );
  }

  void _handleMenuAction(BuildContext context, String action, Song song) {
    switch (action) {
      case 'add_to_queue':
        context.read<MusicProvider>().addToPlayQueue(song);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已将 "${song.title}" 添加到播放队列'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        break;
      case 'add_to_playlist':
        final musicLibraryState = context.findAncestorStateOfType<_MusicLibraryState>();
        musicLibraryState?._showPlaylistSelectionDialog(context, song);
        break;
      case 'song_info':
        _showSongInfo(context, song);
        break;
      case 'edit_info':
        final musicLibraryState = context.findAncestorStateOfType<_MusicLibraryState>();
        musicLibraryState?._showEditSongInfo(context, song);
        break;
      case 'delete':
        _showDeleteConfirmation(context, song);
        break;
    }
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

  void _showDeleteConfirmation(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌曲'),
        content: Text('确定要从音乐库中删除 "${song.title}" 吗？\n\n注意：这只会从音乐库中移除，不会删除原文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              final success = await context.read<MusicProvider>().deleteSong(song.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除 "${song.title}"'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('删除 "${song.title}" 失败'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultIcon(BuildContext context, bool isCurrentSong, MusicProvider musicProvider) {
    final ThemeData theme = Theme.of(context);
    final Color iconColorOnPrimary = theme.colorScheme.onPrimary;
    final Color iconColorOnPrimaryContainer = theme.colorScheme.onPrimaryContainer;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: isCurrentSong ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
      ),
      child: Center(
        child: isCurrentSong
            ? (musicProvider.isPlaying
                ? MusicWaveform(
                    color: iconColorOnPrimary,
                    size: 32,
                  )
                : Icon(
                    Icons.pause,
                    size: 32,
                    color: iconColorOnPrimary,
                  ))
            : Icon(
                Icons.music_note,
                size: 28,
                color: iconColorOnPrimaryContainer,
              ),
      ),
    );
  }
}

class SongGridItem extends StatelessWidget {
  final Song song;
  final int index;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const SongGridItem({
    super.key,
    required this.song,
    required this.index,
    this.isSelectionMode = false,
    this.isSelected = false,
    required this.onTap,
    this.onLongPress,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  List<PopupMenuEntry<String>> _getPopupMenuItems(BuildContext context) {
    return [
      const PopupMenuItem(
        value: 'add_to_queue',
        child: Row(
          children: [
            Icon(Icons.queue_music),
            SizedBox(width: 8),
            Text('添加到播放队列'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'add_to_playlist',
        child: Row(
          children: [
            Icon(Icons.playlist_add),
            SizedBox(width: 8),
            Text('添加到歌单'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'song_info',
        child: Row(
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 8),
            Text('歌曲信息'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'edit_info',
        child: Row(
          children: [
            Icon(Icons.edit_outlined),
            SizedBox(width: 8),
            Text('编辑信息'),
          ],
        ),
      ),
      const PopupMenuItem(
        value: 'delete',
        child: Row(
          children: [
            Icon(Icons.delete_outline),
            SizedBox(width: 8),
            Text('删除'),
          ],
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final isCurrentSong = musicProvider.currentSong?.id == song.id;

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTapUp: (TapUpDetails details) {
            if (!isSelectionMode) {
              final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
              final RelativeRect position = RelativeRect.fromRect(
                Rect.fromPoints(
                  details.globalPosition,
                  details.globalPosition,
                ),
                Offset.zero & overlay.size,
              );

              showMenu<String>(
                context: context,
                position: position,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                items: _getPopupMenuItems(context),
              ).then((String? value) {
                if (value != null) {
                  _handleMenuAction(context, value, song);
                }
              });
            }
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: isCurrentSong ? BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5) : BorderSide.none,
            ),
            clipBehavior: Clip.antiAlias,
            color: isCurrentSong ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                              ),
                              child: song.albumArt != null
                                  ? Image.memory(
                                      song.albumArt!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(context, isCurrentSong, musicProvider),
                                    )
                                  : _buildDefaultIcon(context, isCurrentSong, musicProvider),
                            ),
                          ),
                        ),
                        if (isCurrentSong && musicProvider.isPlaying)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const MusicWaveform(color: Colors.white, size: 26),
                            ),
                          ),
                        if (isCurrentSong && !musicProvider.isPlaying && song.albumArt != null)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.pause_circle_outline, color: Colors.white, size: 30),
                            ),
                          ),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _formatDuration(song.duration),
                              style: const TextStyle(color: Colors.white, fontSize: 11),
                            ),
                          ),
                        ),
                        if (isSelectionMode)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (_) => onTap(),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.title.isNotEmpty ? song.title : '未知歌曲',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.w600,
                                    color: isCurrentSong ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface,
                                    fontSize: 13,
                                  ),
                            ),
                          ),
                          if (song.filePath.toLowerCase().endsWith('.flac'))
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber, width: 1),
                              ),
                              child: Text('FLAC',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.amber.shade700, fontWeight: FontWeight.bold, fontSize: 9)),
                            )
                          else if (song.filePath.toLowerCase().endsWith('.wav'))
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.green, width: 1),
                              ),
                              child: Text('WAV',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 9)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song.artist.isNotEmpty ? song.artist : '未知艺术家',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: isCurrentSong
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.9)
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      if (song.album.isNotEmpty && song.album != 'Unknown Album')
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            song.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: 10,
                                  color: isCurrentSong
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.75)
                                      : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.85),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultIcon(BuildContext context, bool isCurrentSong, MusicProvider musicProvider) {
    final ThemeData theme = Theme.of(context);
    final Color iconColorOnPrimary = theme.colorScheme.onPrimary;
    final Color iconColorOnPrimaryContainer = theme.colorScheme.onPrimaryContainer;

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0),
        color: isCurrentSong ? theme.colorScheme.primary : theme.colorScheme.primaryContainer,
      ),
      child: Center(
        child: isCurrentSong
            ? (musicProvider.isPlaying
                ? MusicWaveform(
                    color: iconColorOnPrimary,
                    size: 32,
                  )
                : Icon(
                    Icons.pause_circle_outline,
                    size: 32,
                    color: iconColorOnPrimary,
                  ))
            : Icon(
                Icons.music_note,
                size: 28,
                color: iconColorOnPrimaryContainer,
              ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, String action, Song song) {
    switch (action) {
      case 'add_to_queue':
        context.read<MusicProvider>().addToPlayQueue(song);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已将 "${song.title}" 添加到播放队列'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        break;
      case 'add_to_playlist':
        final musicLibraryState = context.findAncestorStateOfType<_MusicLibraryState>();
        musicLibraryState?._showPlaylistSelectionDialog(context, song);
        break;
      case 'song_info':
        _showSongInfo(context, song);
        break;
      case 'edit_info':
        final musicLibraryState = context.findAncestorStateOfType<_MusicLibraryState>();
        musicLibraryState?._showEditSongInfo(context, song);
        break;
      case 'delete':
        _showDeleteConfirmation(context, song);
        break;
    }
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

  void _showDeleteConfirmation(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除歌曲'),
        content: Text('确定要从音乐库中删除 "${song.title}" 吗？\n\n注意：这只会从音乐库中移除，不会删除原文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              final success = await context.read<MusicProvider>().deleteSong(song.id);
              if (!context.mounted) return;
              Navigator.pop(context);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除 "${song.title}"'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('删除 "${song.title}" 失败'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}
