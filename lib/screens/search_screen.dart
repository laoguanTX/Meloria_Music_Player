import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';

class SearchTab extends StatefulWidget {
  const SearchTab({super.key});

  @override
  State<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<SearchTab> {
  final TextEditingController _searchController = TextEditingController();
  List<Song> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _isSearching = _searchController.text.isNotEmpty;
      if (_isSearching) {
        _performSearch(_searchController.text);
      } else {
        _searchResults = [];
      }
    });
  }

  void _performSearch(String query) {
    final musicProvider = context.read<MusicProvider>();
    final lowercaseQuery = query.toLowerCase();

    _searchResults = musicProvider.songs.where((song) {
      return song.title.toLowerCase().contains(lowercaseQuery) ||
          song.artist.toLowerCase().contains(lowercaseQuery) ||
          song.album.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
          color: Colors.transparent,
          child: Builder(builder: (context) {
            return NavigationToolbar(
              middle: Text(
                '搜索',
                style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
              ),
              centerMiddle: true,
            );
          }),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: '搜索歌曲、艺术家或专辑...',
              leading: const Icon(Icons.search),
              trailing: _searchController.text.isNotEmpty
                  ? [
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      ),
                    ]
                  : null,
            ),
          ),
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    if (!_isSearching) {
      return const SearchSuggestionsWidget();
    }

    if (_searchResults.isEmpty) {
      return const NoSearchResultsWidget();
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final song = _searchResults[index];
        return SearchResultTile(
          song: song,
          searchQuery: _searchController.text,
          onTap: () {
            final musicProvider = context.read<MusicProvider>();
            final originalIndex = musicProvider.songs.indexOf(song);
            musicProvider.playSong(song, index: originalIndex);
          },
        );
      },
    );
  }
}

class SearchResultTile extends StatelessWidget {
  final Song song;
  final String searchQuery;
  final VoidCallback onTap;
  const SearchResultTile({
    super.key,
    required this.song,
    required this.searchQuery,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) {
        _showContextMenu(context, details.globalPosition);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: song.albumArt != null
                  ? Image.memory(
                      song.albumArt!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.music_note,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        );
                      },
                    )
                  : Icon(
                      Icons.music_note,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
            ),
          ),
          title: _buildHighlightedText(
            song.title,
            searchQuery,
            Theme.of(context).textTheme.titleMedium!,
            Theme.of(context).colorScheme.primary,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHighlightedText(
                song.artist,
                searchQuery,
                Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                Theme.of(context).colorScheme.primary,
              ),
              if (song.album.isNotEmpty && song.album != 'Unknown Album')
                _buildHighlightedText(
                  song.album,
                  searchQuery,
                  Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  Theme.of(context).colorScheme.primary,
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'play',
                child: Row(
                  children: [
                    Icon(Icons.play_arrow),
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
                    Icon(Icons.info_outline),
                    SizedBox(width: 12),
                    Text('歌曲信息'),
                  ],
                ),
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    String text,
    String query,
    TextStyle style,
    Color highlightColor,
  ) {
    if (query.isEmpty) {
      return Text(text, style: style);
    }

    final lowercaseText = text.toLowerCase();
    final lowercaseQuery = query.toLowerCase();

    if (!lowercaseText.contains(lowercaseQuery)) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    int start = 0;
    int index = lowercaseText.indexOf(lowercaseQuery);

    while (index != -1) {
      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: style,
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: style.copyWith(
          color: highlightColor,
          fontWeight: FontWeight.bold,
        ),
      ));

      start = index + query.length;
      index = lowercaseText.indexOf(lowercaseQuery, start);
    }

    if (start < text.length) {
      spans.add(TextSpan(
        text: text.substring(start),
        style: style,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
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

  void _showAddToPlaylistDialog(BuildContext context, Song song) {
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
    final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & overlay.size,
    );

    showMenu<String>(
      context: context,
      position: position,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        const PopupMenuItem(
          value: 'play',
          child: Row(
            children: [
              Icon(Icons.play_arrow),
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
              Icon(Icons.info_outline),
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
    switch (action) {
      case 'play':
        context.read<MusicProvider>().playSong(song);
        break;
      case 'add_to_playlist':
        _showAddToPlaylistDialog(context, song);
        break;
      case 'song_info':
        _showSongInfo(context, song);
        break;
    }
  }
}

class SearchSuggestionsWidget extends StatelessWidget {
  const SearchSuggestionsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '搜索您的音乐',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '输入歌曲名、艺术家或专辑名称',
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
  const NoSearchResultsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '没有找到结果',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '尝试使用不同的关键词',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
