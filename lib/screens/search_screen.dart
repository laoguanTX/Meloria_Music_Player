import 'package:flutter/material.dart'; // 导入Flutter的Material组件库
import 'package:provider/provider.dart'; // 导入Provider状态管理库
import '../providers/music_provider.dart'; // 导入音乐数据提供者
import '../models/song.dart'; // 导入歌曲模型

class SearchTab extends StatefulWidget {
  // 搜索页签组件
  const SearchTab({super.key}); // 构造函数

  @override
  State<SearchTab> createState() => _SearchTabState(); // 创建状态对象
}

class _SearchTabState extends State<SearchTab> {
  // 搜索页签的状态类
  final TextEditingController _searchController = TextEditingController(); // 搜索输入框控制器
  List<Song> _searchResults = []; // 搜索结果列表
  bool _isSearching = false; // 是否正在搜索

  @override
  void initState() {
    // 初始化状态
    super.initState();
    _searchController.addListener(_onSearchChanged); // 监听输入框内容变化
  }

  @override
  void dispose() {
    // 释放资源
    _searchController.removeListener(_onSearchChanged); // 移除监听
    _searchController.dispose(); // 销毁控制器
    super.dispose();
  }

  void _onSearchChanged() {
    // 输入框内容变化时回调
    setState(() {
      _isSearching = _searchController.text.isNotEmpty; // 判断是否有输入
      if (_isSearching) {
        _performSearch(_searchController.text); // 执行搜索
      } else {
        _searchResults = []; // 清空搜索结果
      }
    });
  }

  void _performSearch(String query) {
    // 执行搜索逻辑
    final musicProvider = context.read<MusicProvider>(); // 获取音乐数据提供者
    final lowercaseQuery = query.toLowerCase(); // 转为小写便于匹配

    _searchResults = musicProvider.songs.where((song) {
      // 过滤匹配的歌曲
      return song.title.toLowerCase().contains(lowercaseQuery) || // 标题匹配
          song.artist.toLowerCase().contains(lowercaseQuery) || // 艺术家匹配
          song.album.toLowerCase().contains(lowercaseQuery); // 专辑匹配
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // 构建界面
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight), // 设置AppBar高度
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0), // 内边距
          color: Colors.transparent, // 背景透明
          child: Builder(builder: (context) {
            return NavigationToolbar(
              middle: Text(
                '搜索', // 标题
                style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge, // 标题样式
              ),
              centerMiddle: true, // 居中
            );
          }),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0), // 搜索框外边距
            child: SearchBar(
              controller: _searchController, // 绑定控制器
              hintText: '搜索歌曲、艺术家或专辑...', // 占位提示
              leading: const Icon(Icons.search), // 搜索图标
              trailing: _searchController.text.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear), // 清除按钮
                        onPressed: () {
                          _searchController.clear(); // 清空输入
                        },
                      ),
                    ]
                  : null,
            ),
          ),

          // Search results
          Expanded(
            child: _buildSearchContent(), // 展示搜索内容
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    // 构建搜索内容区域
    if (!_isSearching) {
      return const SearchSuggestionsWidget(); // 未搜索时显示建议
    }

    if (_searchResults.isEmpty) {
      return const NoSearchResultsWidget(); // 无结果时显示提示
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100), // 底部留白
      itemCount: _searchResults.length, // 结果数量
      itemBuilder: (context, index) {
        final song = _searchResults[index]; // 当前歌曲
        return SearchResultTile(
          song: song, // 歌曲对象
          searchQuery: _searchController.text, // 搜索关键字
          onTap: () {
            final musicProvider = context.read<MusicProvider>(); // 获取音乐数据提供者
            final originalIndex = musicProvider.songs.indexOf(song); // 获取原始索引
            musicProvider.playSong(song, index: originalIndex); // 播放歌曲
          },
        );
      },
    );
  }
}

class SearchResultTile extends StatelessWidget {
  // 搜索结果项组件
  final Song song; // 歌曲对象
  final String searchQuery; // 搜索关键字
  final VoidCallback onTap; // 点击回调

  const SearchResultTile({
    super.key,
    required this.song,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // 构建结果项
    return GestureDetector(
      onSecondaryTapDown: (details) {
        // 右键点击时显示弹出菜单
        _showContextMenu(context, details.globalPosition);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), // 外边距
        child: ListTile(
          contentPadding: const EdgeInsets.all(12), // 内容内边距
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8), // 圆角
              color: Theme.of(context).colorScheme.primaryContainer, // 背景色
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // 圆角裁剪
              child: song.albumArt != null
                  ? Image.memory(
                      song.albumArt!, // 使用专辑图片
                      fit: BoxFit.cover, // 填充方式
                      errorBuilder: (context, error, stackTrace) {
                        // 图片加载失败时显示默认图标
                        return Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        );
                      },
                    )
                  : Icon(
                      Icons.music_note, // 无专辑图片时使用图标
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
          ),
          title: _buildHighlightedText(
            song.title, // 歌曲标题
            searchQuery, // 搜索关键字
            Theme.of(context).textTheme.titleMedium!, // 标题样式
            Theme.of(context).colorScheme.primary, // 高亮颜色
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
            children: [
              _buildHighlightedText(
                song.artist, // 艺术家
                searchQuery,
                Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                Theme.of(context).colorScheme.primary,
              ),
              if (song.album.isNotEmpty && song.album != 'Unknown Album')
                _buildHighlightedText(
                  song.album, // 专辑
                  searchQuery,
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert), // 更多操作按钮
            onSelected: (value) => _handleMenuAction(context, value),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // 添加圆角
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'play',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow), // 播放图标
                    SizedBox(width: 12),
                    Text('播放'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'add_to_playlist',
                child: Row(
                  children: [
                    Icon(Icons.playlist_add),
                    SizedBox(width: 12),
                    Text('添加到歌单'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'song_info',
                child: Row(
                  children: [
                    Icon(Icons.info_outline), // 信息图标
                    SizedBox(width: 12),
                    Text('歌曲信息'),
                  ],
                ),
              ),
            ],
          ),
          onTap: onTap, // 点击播放
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text, // 原始文本
    String query, // 搜索关键字
    TextStyle style, // 文本样式
    Color highlightColor, // 高亮颜色
  ) {
    if (query.isEmpty) {
      return Text(text, style: style); // 无关键字直接返回
    }

    final lowercaseText = text.toLowerCase(); // 转小写
    final lowercaseQuery = query.toLowerCase(); // 转小写

    if (!lowercaseText.contains(lowercaseQuery)) {
      return Text(text, style: style); // 不包含关键字直接返回
    }

    final spans = <TextSpan>[]; // 富文本片段
    int start = 0;
    int index = lowercaseText.indexOf(lowercaseQuery); // 查找关键字

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index), // 普通文本
          style: style,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length), // 高亮文本
        style: style.copyWith(
          color: highlightColor,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = lowercaseText.indexOf(lowercaseQuery, start); // 查找下一个
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start), // 剩余文本
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans), // 返回富文本
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
    // 显示歌曲信息对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('歌曲信息'), // 标题
        content: Column(
          mainAxisSize: MainAxisSize.min, // 最小高度
          crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
          children: [
            _buildInfoRow('标题', song.title), // 歌曲标题
            _buildInfoRow('艺术家', song.artist), // 艺术家
            _buildInfoRow('专辑', song.album), // 专辑
            _buildInfoRow('文件路径', song.filePath), // 文件路径
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 关闭按钮
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    // 构建信息行
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4), // 上下间距
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start, // 左对齐
        children: [
          SizedBox(
            width: 80, // 标签宽度
            child: Text(
              '$label:', // 标签
              style: const TextStyle(fontWeight: FontWeight.bold), // 加粗
            ),
          ),
          Expanded(
            child: Text(value), // 值
          ),
        ],
      ),
    );
  }

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
    // 显示添加到歌单对话框
    final musicProvider = context.read<MusicProvider>();
    final playlists = musicProvider.playlists;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加到歌单'),
        content: playlists.isEmpty
            ? const Text('暂无歌单，请先创建歌单')
            : SizedBox(
                width: MediaQuery.of(context).size.width * 0.5,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final playlist = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(playlist.name),
                      subtitle: Text('${playlist.songIds.length} 首歌曲'),
                      onTap: () async {
                        Navigator.pop(context);
                        await musicProvider.addSongsToPlaylist(playlist.id, [song.id]);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('已将 "${song.title}" 添加到歌单 "${playlist.name}"'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          if (playlists.isEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(context, song);
              },
              child: const Text('创建歌单'),
            ),
        ],
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, Song song) {
    // 显示创建歌单对话框
    final TextEditingController playlistNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建新歌单'),
        content: TextField(
          controller: playlistNameController,
          decoration: const InputDecoration(
            labelText: '歌单名称',
            hintText: '请输入歌单名称',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final playlistName = playlistNameController.text.trim();
              if (playlistName.isNotEmpty) {
                Navigator.pop(context);
                final musicProvider = context.read<MusicProvider>();
                await musicProvider.createPlaylist(playlistName);
                // 创建后立即添加歌曲到新歌单
                final newPlaylist = musicProvider.playlists.last;
                await musicProvider.addSongsToPlaylist(newPlaylist.id, [song.id]);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('已创建歌单 "$playlistName" 并添加了 "${song.title}"'),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    // 显示右键菜单
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12), // 添加圆角
      ),
      items: [
        const PopupMenuItem(
          value: 'play',
          child: Row(
            children: [
              Icon(Icons.play_arrow), // 播放图标
              SizedBox(width: 12),
              Text('播放'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'add_to_playlist',
          child: Row(
            children: [
              Icon(Icons.playlist_add),
              SizedBox(width: 12),
              Text('添加到歌单'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'song_info',
          child: Row(
            children: [
              Icon(Icons.info_outline), // 信息图标
              SizedBox(width: 12),
              Text('歌曲信息'),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value != null && context.mounted) {
        _handleMenuAction(context, value);
      }
    });
  }

  void _handleMenuAction(BuildContext context, String action) {
    // 处理菜单操作
    switch (action) {
      case 'play':
        context.read<MusicProvider>().playSong(song); // 播放歌曲
        break;
      case 'add_to_playlist':
        _showAddToPlaylistDialog(context, song); // 显示添加到歌单对话框
        break;
      case 'song_info':
        _showSongInfo(context, song); // 弹出歌曲信息
        break;
    }
  }
}

class SearchSuggestionsWidget extends StatelessWidget {
  // 搜索建议组件
  const SearchSuggestionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 构建建议界面
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 居中
        children: [
          Icon(
            Icons.search_outlined, // 搜索图标
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant, // 图标颜色
          ),
          const SizedBox(height: 16), // 间距
          Text(
            '搜索您的音乐', // 提示文字
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8), // 间距
          Text(
            '输入歌曲名、艺术家或专辑名称', // 说明文字
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class NoSearchResultsWidget extends StatelessWidget {
  // 无搜索结果组件
  const NoSearchResultsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // 构建无结果界面
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // 居中
        children: [
          Icon(
            Icons.search_off_outlined, // 无结果图标
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant, // 图标颜色
          ),
          const SizedBox(height: 16), // 间距
          Text(
            '没有找到结果', // 无结果提示
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8), // 间距
          Text(
            '尝试使用不同的关键词', // 建议文字
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
