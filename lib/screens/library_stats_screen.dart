import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';

class LibraryStatsScreen extends StatefulWidget {
  const LibraryStatsScreen({super.key});

  @override
  State<LibraryStatsScreen> createState() => _LibraryStatsScreenState();
}

class _LibraryStatsScreenState extends State<LibraryStatsScreen> {
  Future<Map<String, int>>? _libraryStatsFuture;

  @override
  void initState() {
    super.initState();
    // Fetch initial stats once. listen:false to prevent initState re-running.
    _libraryStatsFuture = Provider.of<MusicProvider>(context, listen: false).getLibraryStats();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight), // Consistent height
        child: Container(
          padding: const EdgeInsets.only(
            top: 20.0,
            left: 20.0,
            right: 20.0,
            // bottom: 0 removed, as MusicLibrary doesn't have it, aiming for consistency
          ),
          color: Colors.transparent,
          child: Builder(builder: (context) {
            return NavigationToolbar(
              leading: null,
              middle: Text(
                '音乐库统计',
                style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
              ),
              centerMiddle: true, // Center the title
            );
          }),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Map<String, int>>(
          future: _libraryStatsFuture, // Use the stored future
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('加载统计信息失败: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
              return const Center(child: Text('暂无统计信息'));
            }

            final initialDbStats = snapshot.data!;

            return Consumer<MusicProvider>(
              builder: (context, musicProvider, child) {
                final totalSongsFromDb = initialDbStats['total'] ?? 0; // Use DB count from future
                final livePlaylistsCount = musicProvider.playlists.length;
                final uniqueAlbumsCount = musicProvider.getUniqueAlbums().length;
                final uniqueArtistsCount = musicProvider.getUniqueArtists().length;
                final totalDurationOfSongs = musicProvider.getTotalDurationOfSongs();
                final mostPlayedSongs = musicProvider.getMostPlayedSongs(count: 3);

                return ListView(
                  children: <Widget>[
                    ListTile(
                      leading: const Icon(Icons.music_note),
                      title: const Text('总歌曲数量 (来自数据库)'),
                      trailing: Text('$totalSongsFromDb 首', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ListTile(
                      leading: const Icon(Icons.album),
                      title: const Text('总专辑数量'),
                      trailing: Text('$uniqueAlbumsCount 张', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('总艺术家数量'),
                      trailing: Text('$uniqueArtistsCount 位', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: const Text('播放列表数量'),
                      trailing: Text('$livePlaylistsCount 个', style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.timer_outlined),
                      title: const Text('歌曲总时长'),
                      trailing: Text(_formatDuration(totalDurationOfSongs), style: Theme.of(context).textTheme.titleMedium),
                    ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '最常播放',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (mostPlayedSongs.isEmpty)
                      const ListTile(
                        title: Text('暂无播放记录'),
                      )
                    else
                      ...mostPlayedSongs.map((song) => ListTile(
                            leading: song.albumArt != null && song.albumArt!.isNotEmpty
                                ? Image.memory(song.albumArt!, width: 40, height: 40, fit: BoxFit.cover)
                                : const Icon(Icons.music_note, size: 40),
                            title: Text(song.title),
                            subtitle: Text(song.artist),
                            trailing: Text('播放 ${song.playCount} 次',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontSize: Theme.of(context).textTheme.bodyMedium?.fontSize)), // Adjusted for trailing context
                          )),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        '更多统计信息待添加...',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
