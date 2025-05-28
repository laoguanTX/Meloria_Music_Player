import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';

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
        content: Text(
            '确定要删除选中的 ${_selectedSongs.length} 首歌曲吗？\n\n注意：这只会从音乐库中移除，不会删除原文件。'),
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
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      // 执行批量删除
      final success = await context
          .read<MusicProvider>()
          .deleteSongs(_selectedSongs.toList());
      if (!mounted) return;
      // 关闭加载指示器
      Navigator.pop(context);

      // 显示结果
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已删除 ${_selectedSongs.length} 首歌曲'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        _toggleSelectionMode(); // 退出选择模式
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSelectionMode
            ? Text('已选择 ${_selectedSongs.length} 首')
            : const Text('音乐库'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_isSelectionMode) ...[
            if (_selectedSongs.isEmpty)
              Consumer<MusicProvider>(
                builder: (context, musicProvider, child) {
                  return IconButton(
                    icon: const Icon(Icons.select_all),
                    onPressed: () => _selectAll(musicProvider.songs),
                    tooltip: '全选',
                  );
                },
              )
            else
              IconButton(
                icon: const Icon(Icons.deselect),
                onPressed: _deselectAll,
                tooltip: '取消全选',
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed:
                  _selectedSongs.isNotEmpty ? _deleteSelectedSongs : null,
              tooltip: '删除选中',
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip: '批量选择',
            ),
            IconButton(
              icon: const Icon(Icons.sort),
              onPressed: () {
                _showSortOptions(context);
              },
              tooltip: '排序',
            ),
          ],
        ],
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          if (musicProvider.songs.isEmpty) {
            return const EmptyLibraryWidget();
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: musicProvider.songs.length,
            itemBuilder: (context, index) {
              final song = musicProvider.songs[index];
              return SongListTile(
                song: song,
                index: index,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedSongs.contains(song.id),
                onTap: _isSelectionMode
                    ? () => _toggleSongSelection(song.id)
                    : () => musicProvider.playSong(song, index: index),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        final isCurrentSong = musicProvider.currentSong?.id == song.id;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: isSelected
              ? Theme.of(context)
                  .colorScheme
                  .primaryContainer
                  .withValues(alpha: 0.3)
              : null,
          child: ListTile(
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isCurrentSong
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.primaryContainer,
                    ),
                    child: Icon(
                      isCurrentSong && musicProvider.isPlaying
                          ? Icons.graphic_eq
                          : Icons.music_note,
                      color: isCurrentSong
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onPrimaryContainer,
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
                          color: isCurrentSong
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontWeight: isCurrentSong ? FontWeight.bold : null,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 显示音频格式标签
                if (song.filePath.toLowerCase().endsWith('.flac'))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
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
            subtitle: Column(
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
            trailing: isSelectionMode
                ? null
                : PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      _handleMenuAction(context, value, song);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'add_to_playlist',
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add),
                            SizedBox(width: 8),
                            Text('添加到播放列表'),
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
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline),
                            SizedBox(width: 8),
                            Text('删除'),
                          ],
                        ),
                      ),
                    ],
                  ),
            onTap: onTap,
            onLongPress: onLongPress,
          ),
        );
      },
    );
  }

  void _handleMenuAction(BuildContext context, String action, Song song) {
    switch (action) {
      case 'add_to_playlist':
        // 调用顶层的播放列表选择对话框
        final musicLibraryState =
            context.findAncestorStateOfType<_MusicLibraryState>();
        musicLibraryState?._showPlaylistSelectionDialog(context, song);
        break;
      case 'song_info':
        _showSongInfo(context, song);
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
        content:
            Text('确定要从音乐库中删除 "${song.title}" 吗？\n\n注意：这只会从音乐库中移除，不会删除原文件。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              // 显示加载指示器
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              // 执行删除操作
              final success =
                  await context.read<MusicProvider>().deleteSong(song.id);
              if (context.mounted) {
                // 关闭加载指示器
                Navigator.pop(context);
                // 显示结果
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
              }
            },
            child: const Text('删除'),
          ),
        ],
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
