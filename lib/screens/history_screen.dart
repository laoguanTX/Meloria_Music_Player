// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:music_player/models/song.dart';
import 'package:music_player/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'package:music_player/widgets/music_waveform.dart'; // Import for waveform

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final history = musicProvider.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('播放历史'),
        actions: [
          if (history.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10.0),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: '清空播放历史',
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('清空播放历史'),
                      content: const Text('确定要清空所有播放历史记录吗？'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('清空'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    if (!context.mounted) return;
                    await musicProvider.clearAllHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('播放历史已清空'),
                        backgroundColor: Theme.of(context).colorScheme.primary,
                      ),
                    );
                  }
                },
              ),
            ),
        ],
      ),
      body: history.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_outlined, size: 80),
                  SizedBox(height: 16),
                  Text('还没有播放历史'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final song = history[index];
                return HistorySongListItem(
                  song: song,
                  musicProvider: musicProvider,
                  onTap: () {
                    // When playing from history, we don't want to update the history again.
                    // Use playSongWithoutHistory to avoid moving the song to the top of history.
                    int originalIndex = musicProvider.songs.indexWhere((s) => s.id == song.id);
                    musicProvider.playSongWithoutHistory(song, index: originalIndex != -1 ? originalIndex : null);
                  },
                );
              },
            ),
    );
  }
}

class HistorySongListItem extends StatelessWidget {
  final Song song;
  final MusicProvider musicProvider;
  final VoidCallback? onTap;

  const HistorySongListItem({
    super.key,
    required this.song,
    required this.musicProvider,
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
            leading: const Icon(Icons.queue_music),
            title: const Text('添加到播放队列'),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              // When adding a song from history to the queue, we don't want to update history again
              musicProvider.playSongWithoutHistory(song);
              ScaffoldMessenger.of(tileContext).showSnackBar(
                SnackBar(
                  content: Text('已将 "${song.title}" 添加到播放队列并开始播放'),
                  backgroundColor: Theme.of(tileContext).colorScheme.primary,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('从历史记录中删除'),
            onTap: () async {
              Navigator.pop(bottomSheetBuildContext);
              final confirmed = await showDialog<bool>(
                context: tileContext,
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
                if (!tileContext.mounted) return;
                await musicProvider.removeFromHistory(song.id);
                ScaffoldMessenger.of(tileContext).showSnackBar(
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: Image.memory(song.albumArt!, height: 100, width: 100, fit: BoxFit.cover),
                  ),
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
    final isCurrentSong = musicProvider.currentSong?.id == song.id;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(
          color: isCurrentSong ? colorScheme.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      color: isCurrentSong ? colorScheme.primaryContainer.withOpacity(0.3) : colorScheme.surfaceVariant.withOpacity(0.3),
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              SizedBox(
                width: 50,
                height: 50,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: song.albumArt != null
                          ? Image.memory(
                              song.albumArt!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(Icons.music_note, size: 30, color: colorScheme.onSurfaceVariant),
                            )
                          : Icon(Icons.music_note, size: 30, color: colorScheme.onSurfaceVariant),
                    ),
                    if (isCurrentSong && musicProvider.isPlaying)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: MusicWaveform(
                          color: Theme.of(context).colorScheme.primary,
                          size: 24, // 使用 size 参数代替 barCount, barWidth, barHeightFactor
                        ),
                      ),
                    if (isCurrentSong && !musicProvider.isPlaying && musicProvider.playerState != PlayerState.stopped)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Icon(Icons.pause, color: colorScheme.primary, size: 30),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: isCurrentSong ? FontWeight.bold : FontWeight.normal,
                            color: isCurrentSong ? colorScheme.primary : colorScheme.onSurface,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist.isNotEmpty ? song.artist : '未知艺术家',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isCurrentSong ? colorScheme.primary.withOpacity(0.8) : colorScheme.onSurfaceVariant,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(song.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isCurrentSong ? colorScheme.primary : colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(width: 4), // Reduced spacing before menu button
              IconButton(
                icon: const Icon(Icons.more_vert),
                iconSize: 20,
                color: colorScheme.onSurfaceVariant,
                tooltip: '更多选项',
                onPressed: () => _showSongMenu(context, song, musicProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
