// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../widgets/bottom_player.dart';
import '../widgets/music_library.dart';
import '../widgets/playlists_tab.dart';
import '../widgets/search_tab.dart';
import '../widgets/custom_status_bar.dart'; // 现在包含 HomeCustomStatusBar
import '../widgets/folder_tab.dart'; // 新增导入

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Widget> _pages = [
    const MusicLibrary(),
    const PlaylistsTab(),
    const SearchTab(),
    const FolderTab(), // 新增页面
  ];
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 获取主题颜色并使其更浅
    final navigationRailBackgroundColor = Color.alphaBlend(
      Colors.white.withOpacity(0.03), // 你可以调整这个透明度来控制浅色的程度
      theme.colorScheme.surface,
    );

    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return HomeCustomStatusBar(
            // 修改为 HomeCustomStatusBar
            homeScreenBackgroundColor: theme.colorScheme.surface,
            child: Scaffold(
              body: Row(
                children: [
                  // 左侧导航栏
                  Container(
                    // 使用 Container 来添加圆角和自定义背景色
                    decoration: BoxDecoration(
                      color: navigationRailBackgroundColor,
                      borderRadius: const BorderRadius.only(
                        // 添加圆角
                        topRight: Radius.circular(16.0),
                        bottomRight: Radius.circular(16.0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: NavigationRail(
                            backgroundColor:
                                Colors.transparent, // 设置为透明，因为父Container会处理背景色
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: (index) {
                              setState(() {
                                _selectedIndex = index;
                              });
                            },
                            extended: MediaQuery.of(context).size.width > 800,
                            destinations: const [
                              NavigationRailDestination(
                                icon: Icon(Icons.library_music_outlined),
                                selectedIcon: Icon(Icons.library_music),
                                label: Text('音乐库'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.playlist_play_outlined),
                                selectedIcon: Icon(Icons.playlist_play),
                                label: Text('播放列表'),
                              ),
                              NavigationRailDestination(
                                icon: Icon(Icons.search_outlined),
                                selectedIcon: Icon(Icons.search),
                                label: Text('搜索'),
                              ),
                              NavigationRailDestination(
                                // 新增目标
                                icon: Icon(Icons.folder_outlined),
                                selectedIcon: Icon(Icons.folder),
                                label: Text('文件夹'),
                              ),
                            ],
                          ),
                        ),
                        // 在侧边栏底部始终显示音乐库统计
                        const LibraryStatsInSidebar(),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: _pages[_selectedIndex],
                        ),
                        if (musicProvider.currentSong != null)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).viewPadding.bottom,
                            ),
                            child: const BottomPlayer(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ));
      },
    );
  }
}

// 侧边栏底部的音乐库统计组件
class LibraryStatsInSidebar extends StatelessWidget {
  const LibraryStatsInSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return FutureBuilder<Map<String, int>>(
          future: musicProvider.getLibraryStats(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || musicProvider.songs.isEmpty) {
              return const SizedBox.shrink();
            }

            final stats = snapshot.data!;
            final isExtended = MediaQuery.of(context).size.width > 800;
            return Container(
              width: isExtended ? 256 : 72,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isExtended
                  ? Column(
                      children: [
                        Text(
                          '音乐库统计',
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          children: [
                            _buildVerticalStatItem(context, '${stats['total']}',
                                '总歌曲', Icons.music_note, Colors.blue),
                            const SizedBox(height: 8),
                            _buildVerticalStatItem(
                                context,
                                '${stats['playlists']}',
                                '播放列表',
                                Icons.playlist_play,
                                Colors.purple),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.music_note,
                                size: 20,
                                color: Colors.blue,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stats['total']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.playlist_play,
                                size: 20,
                                color: Colors.purple,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${stats['playlists']}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerticalStatItem(BuildContext context, String count,
      String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                count,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
