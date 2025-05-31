import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';

class PlaylistsTab extends StatelessWidget {
  const PlaylistsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight), // Consistent height
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
          color: Colors.transparent,
          child: Builder(builder: (context) {
            return NavigationToolbar(
              leading: null,
              middle: Text(
                '播放列表',
                style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _showCreatePlaylistDialog(context);
                    },
                  ),
                ],
              ),
              centerMiddle: true, // Set to true if you want the title centered like a typical AppBar
            );
          }),
        ),
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          if (musicProvider.playlists.isEmpty) {
            return const EmptyPlaylistsWidget();
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100),
            itemCount: musicProvider.playlists.length,
            itemBuilder: (context, index) {
              final playlist = musicProvider.playlists[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.secondaryContainer,
                    ),
                    child: Icon(
                      Icons.queue_music,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    playlist.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${playlist.songs.length} 首歌曲',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      _handlePlaylistAction(context, value, playlist.id);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'play',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow),
                            SizedBox(width: 8),
                            Text('播放'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('重命名'),
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
                  onTap: () {
                    // 暂时显示一个简单的对话框，后续可以创建详细页面
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(playlist.name),
                        content: Text('播放列表包含 ${playlist.songs.length} 首歌曲'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('关闭'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建播放列表'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '播放列表名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<MusicProvider>().createPlaylist(controller.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已创建播放列表 "${controller.text.trim()}"'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _handlePlaylistAction(BuildContext context, String action, String playlistId) {
    switch (action) {
      case 'play':
        context.read<MusicProvider>().playPlaylist(playlistId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始播放播放列表'),
          ),
        );
        break;
      case 'rename':
        _showRenamePlaylistDialog(context, playlistId);
        break;
      case 'delete':
        _showDeletePlaylistDialog(context, playlistId);
        break;
    }
  }

  void _showDeletePlaylistDialog(BuildContext context, String playlistId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播放列表'),
        content: const Text('确定要删除这个播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<MusicProvider>().deletePlaylist(playlistId);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('播放列表已删除'),
                ),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _showRenamePlaylistDialog(BuildContext context, String playlistId) {
    final playlist = context.read<MusicProvider>().playlists.firstWhere((p) => p.id == playlistId);
    final controller = TextEditingController(text: playlist.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名播放列表'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '播放列表名称',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<MusicProvider>().renamePlaylist(playlistId, controller.text.trim());
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已重命名为 "${controller.text.trim()}"'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            },
            child: const Text('重命名'),
          ),
        ],
      ),
    );
  }
}

class EmptyPlaylistsWidget extends StatelessWidget {
  const EmptyPlaylistsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.queue_music_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '没有播放列表',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '创建您的第一个播放列表',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              // 直接调用创建播放列表的逻辑
              final controller = TextEditingController();
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('创建播放列表'),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      labelText: '播放列表名称',
                      border: OutlineInputBorder(),
                    ),
                    autofocus: true,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          context.read<MusicProvider>().createPlaylist(controller.text.trim());
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已创建播放列表 "${controller.text.trim()}"'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                      },
                      child: const Text('创建'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('创建播放列表'),
          ),
        ],
      ),
    );
  }
}
