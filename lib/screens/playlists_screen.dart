import 'package:flutter/material.dart'; // 导入Flutter的Material组件库
import 'package:provider/provider.dart'; // 导入Provider状态管理库
import '../providers/music_provider.dart'; // 导入音乐数据提供者

class PlaylistsTab extends StatelessWidget {
  // 播放列表页签组件
  const PlaylistsTab({super.key}); // 构造函数

  @override
  Widget build(BuildContext context) {
    // 构建界面
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight), // 设置AppBar高度
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0), // AppBar内边距
          color: Colors.transparent, // 背景透明
          child: Builder(builder: (context) {
            return NavigationToolbar(
              leading: null, // 不显示返回按钮
              middle: Text(
                '播放列表', // 标题
                style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge, // 标题样式
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min, // 最小主轴尺寸
                children: [
                  IconButton(
                    icon: const Icon(Icons.add), // 添加按钮
                    onPressed: () {
                      _showCreatePlaylistDialog(context); // 显示创建播放列表对话框
                    },
                  ),
                ],
              ),
              centerMiddle: true, // 标题居中
            );
          }),
        ),
      ),
      body: Consumer<MusicProvider>(
        builder: (context, musicProvider, child) {
          if (musicProvider.playlists.isEmpty) {
            return const EmptyPlaylistsWidget(); // 无播放列表时显示提示
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 100), // 底部留白
            itemCount: musicProvider.playlists.length, // 播放列表数量
            itemBuilder: (context, index) {
              final playlist = musicProvider.playlists[index]; // 当前播放列表
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 外边距
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12), // 内容内边距
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8), // 圆角
                      color: Theme.of(context).colorScheme.secondaryContainer, // 背景色
                    ),
                    child: Icon(
                      Icons.queue_music, // 播放列表图标
                      color: Theme.of(context).colorScheme.onSecondaryContainer, // 图标颜色
                    ),
                  ),
                  title: Text(
                    playlist.name, // 播放列表名称
                    style: Theme.of(context).textTheme.titleMedium, // 标题样式
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis, // 超出省略
                  ),
                  subtitle: Text(
                    '${playlist.songs.length} 首歌曲', // 歌曲数量
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  trailing: PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert), // 更多操作按钮
                    onSelected: (value) {
                      _handlePlaylistAction(context, value, playlist.id); // 处理操作
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'play',
                        child: Row(
                          children: [
                            Icon(Icons.play_arrow), // 播放
                            SizedBox(width: 8),
                            Text('播放'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'rename',
                        child: Row(
                          children: [
                            Icon(Icons.edit), // 重命名
                            SizedBox(width: 8),
                            Text('重命名'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline), // 删除
                            SizedBox(width: 8),
                            Text('删除'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(playlist.name), // 播放列表名称
                        content: Text('播放列表包含 ${playlist.songs.length} 首歌曲'), // 歌曲数量
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context), // 关闭按钮
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
    // 显示创建播放列表对话框
    final TextEditingController controller = TextEditingController(); // 输入框控制器

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建播放列表'), // 标题
        content: TextField(
          controller: controller, // 绑定控制器
          decoration: const InputDecoration(
            labelText: '播放列表名称', // 输入提示
            border: OutlineInputBorder(), // 边框
          ),
          autofocus: true, // 自动聚焦
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消按钮
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<MusicProvider>().createPlaylist(controller.text.trim()); // 创建播放列表
                Navigator.pop(context); // 关闭对话框
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已创建播放列表 "${controller.text.trim()}"'), // 创建成功提示
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
    // 处理播放列表操作
    switch (action) {
      case 'play':
        context.read<MusicProvider>().playPlaylist(playlistId); // 播放播放列表
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('开始播放播放列表'), // 播放提示
          ),
        );
        break;
      case 'rename':
        _showRenamePlaylistDialog(context, playlistId); // 重命名
        break;
      case 'delete':
        _showDeletePlaylistDialog(context, playlistId); // 删除
        break;
    }
  }

  void _showDeletePlaylistDialog(BuildContext context, String playlistId) {
    // 显示删除对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播放列表'), // 标题
        content: const Text('确定要删除这个播放列表吗？'), // 提示
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消按钮
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              context.read<MusicProvider>().deletePlaylist(playlistId); // 删除播放列表
              Navigator.pop(context); // 关闭对话框
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('播放列表已删除'), // 删除成功提示
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
    // 显示重命名对话框
    final playlist = context.read<MusicProvider>().playlists.firstWhere((p) => p.id == playlistId); // 查找播放列表
    final controller = TextEditingController(text: playlist.name); // 输入框控制器

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名播放列表'), // 标题
        content: TextField(
          controller: controller, // 绑定控制器
          decoration: const InputDecoration(
            labelText: '播放列表名称', // 输入提示
            border: OutlineInputBorder(), // 边框
          ),
          autofocus: true, // 自动聚焦
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 取消按钮
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<MusicProvider>().renamePlaylist(playlistId, controller.text.trim()); // 重命名播放列表
                Navigator.pop(context); // 关闭对话框
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已重命名为 "${controller.text.trim()}"'), // 重命名成功提示
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
  // 空播放列表提示组件
  const EmptyPlaylistsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 构建界面
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 居中
        children: [
          Icon(
            Icons.queue_music_outlined, // 图标
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant, // 图标颜色
          ),
          const SizedBox(height: 16), // 间距
          Text(
            '没有播放列表', // 提示文字
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8), // 间距
          Text(
            '创建您的第一个播放列表', // 说明文字
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24), // 间距
          FilledButton.icon(
            onPressed: () {
              final controller = TextEditingController(); // 输入框控制器
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('创建播放列表'), // 标题
                  content: TextField(
                    controller: controller, // 绑定控制器
                    decoration: const InputDecoration(
                      labelText: '播放列表名称', // 输入提示
                      border: OutlineInputBorder(), // 边框
                    ),
                    autofocus: true, // 自动聚焦
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context), // 取消按钮
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () {
                        if (controller.text.trim().isNotEmpty) {
                          context.read<MusicProvider>().createPlaylist(controller.text.trim()); // 创建播放列表
                          Navigator.pop(context); // 关闭对话框
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已创建播放列表 "${controller.text.trim()}"'), // 创建成功提示
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
            icon: const Icon(Icons.add), // 添加图标
            label: const Text('创建播放列表'), // 按钮文字
          ),
        ],
      ),
    );
  }
}
