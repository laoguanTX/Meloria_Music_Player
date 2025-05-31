import 'package:flutter/material.dart';
import 'package:music_player/models/song.dart';
import 'package:music_player/providers/music_provider.dart';
import 'package:provider/provider.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final history = musicProvider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
      ),
      body: history.isEmpty
          ? const Center(
              child: Text('还没有播放历史'),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // 与 music_library.dart 保持一致
              itemCount: history.length,
              itemBuilder: (context, index) {
                final song = history[index];
                return HistorySongListTile(
                  // Use the new HistorySongListTile
                  song: song,
                  index: index, // 当前歌曲在历史列表中的索引
                  onTap: () {
                    // 点击歌曲进行播放
                    // 将当前历史记录中的歌曲索引传递给 playSong
                    // 确保播放的是历史记录列表中的歌曲，而不是主歌曲列表
                    musicProvider.playSong(song, index: musicProvider.songs.indexOf(song));
                  },
                );
              },
            ),
    );
  }
}

// Copied and modified SongListTile for History Screen
class HistorySongListTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback? onTap;

  const HistorySongListTile({
    super.key,
    required this.song,
    required this.index,
    this.onTap,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _showSongMenu(BuildContext tileContext, Song song, MusicProvider musicProvider) {
    showModalBottomSheet(
      context: tileContext,
      builder: (bottomSheetBuildContext) => Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('添加到播放列表'),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              _showPlaylistSelectionDialog(tileContext, song, musicProvider);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('从历史记录中删除'),
            onTap: () async {
              Navigator.pop(bottomSheetBuildContext);

              final confirmed = await showDialog<bool>(
                context: tileContext, // Use tileContext for the confirmation dialog
                builder: (dialogContext) => AlertDialog(
                  title: const Text('从历史记录中删除'),
                  content: Text('确定要从播放历史中删除 "${song.title}" 吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('删除'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                if (!tileContext.mounted) return; // Check mounted status of tileContext
                musicProvider.removeFromHistory(song.id);
                ScaffoldMessenger.of(tileContext).showSnackBar(
                  // Use tileContext
                  SnackBar(
                    content: Text('已从历史记录中删除 "${song.title}"'),
                    backgroundColor: Theme.of(tileContext).colorScheme.primary,
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('歌曲信息'),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              _showSongInfoDialog(tileContext, song);
            },
          ),
        ],
      ),
    );
  }

  void _showPlaylistSelectionDialog(BuildContext parentContext, Song song, MusicProvider musicProvider) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('添加到播放列表'),
        content: Consumer<MusicProvider>(
          builder: (context, provider, child) {
            if (provider.playlists.isEmpty) {
              return const Text('暂无播放列表\\n请先创建一个播放列表');
            }
            return SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: provider.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = provider.playlists[index];
                  return ListTile(
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.songs.length} 首歌曲'),
                    onTap: () async {
                      await provider.addSongToPlaylist(playlist.id, song);

                      Navigator.pop(dialogContext); // Pop the current dialog first

                      if (!parentContext.mounted) return; // Check parentContext (tileContext)
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        // Use parentContext (tileContext)
                        SnackBar(
                          content: Text('已添加到 "${playlist.name}"'),
                          backgroundColor: Theme.of(parentContext).colorScheme.primary,
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showSongInfoDialog(BuildContext parentContext, Song song) {
    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('歌曲信息'),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              if (song.albumArt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Image.memory(song.albumArt!, height: 100, width: 100, fit: BoxFit.cover),
                ),
              Text('标题: ${song.title}'),
              Text('艺术家: ${song.artist.isNotEmpty ? song.artist : '未知'}'),
              Text('专辑: ${song.album.isNotEmpty ? song.album : '未知'}'),
              Text('时长: ${_formatDuration(song.duration)}'),
              Text('路径: ${song.filePath}'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('关闭'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final currentSong = musicProvider.currentSong;
    final isPlaying = musicProvider.isPlaying && currentSong?.id == song.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              // Album Art or Placeholder
              SizedBox(
                width: 50,
                height: 50,
                child: song.albumArt != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.memory(
                          song.albumArt!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, size: 30),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Icon(Icons.music_note, size: 30),
                      ),
              ),
              const SizedBox(width: 16),
              // Song Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isPlaying ? Theme.of(context).colorScheme.primary : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist.isNotEmpty ? song.artist : '未知艺术家',
                      style: TextStyle(
                        fontSize: 14,
                        color: isPlaying ? Theme.of(context).colorScheme.primary.withOpacity(0.8) : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Duration and More Options
              Text(
                _formatDuration(song.duration),
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert),
                onPressed: () => _showSongMenu(context, song, musicProvider),
                tooltip: '更多选项',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
