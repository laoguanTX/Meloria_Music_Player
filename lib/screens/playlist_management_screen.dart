// filepath: e:\VSCode\Flutter\music_player\lib\screens\playlist_management_screen.dart
// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/playlist.dart';
import '../models/song.dart'; // Added for Song model
import '../widgets/music_waveform.dart'; // Added for MusicWaveform, keep if used in detail view
import './add_songs_screen.dart';

class PlaylistManagementScreen extends StatefulWidget {
  const PlaylistManagementScreen({super.key});

  @override
  State<PlaylistManagementScreen> createState() => _PlaylistManagementScreenState();
}

class _PlaylistManagementScreenState extends State<PlaylistManagementScreen> {
  final TextEditingController _playlistNameController = TextEditingController();
  Playlist? _selectedPlaylist;

  // 批量删除相关状态
  bool _isMultiSelectMode = false;
  final Set<String> _selectedSongIds = {};

  static const Key playlistListScaffoldKey = ValueKey('playlist_list_scaffold'); // Added static key

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  void _showCreatePlaylistDialog({Playlist? playlistToEdit}) {
    if (playlistToEdit != null) {
      _playlistNameController.text = playlistToEdit.name;
    } else {
      _playlistNameController.clear();
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            playlistToEdit == null ? '创建歌单' : '重命名歌单',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          content: TextField(
            controller: _playlistNameController,
            decoration: const InputDecoration(hintText: '歌单名称'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                final name = _playlistNameController.text.trim();
                if (name.isNotEmpty) {
                  final musicProvider = Provider.of<MusicProvider>(context, listen: false);
                  if (playlistToEdit == null) {
                    musicProvider.createPlaylist(name);
                  } else {
                    musicProvider.renamePlaylist(playlistToEdit.id, name);
                  }
                  Navigator.of(context).pop();
                  // If editing the selected playlist, update its name in the detail view
                  if (_selectedPlaylist != null && _selectedPlaylist!.id == playlistToEdit?.id) {
                    setState(() {
                      // Ensure the playlist is updated from the provider to reflect the new name
                      _selectedPlaylist = musicProvider.playlists.firstWhere((p) => p.id == _selectedPlaylist!.id, orElse: () => _selectedPlaylist!);
                    });
                  }
                }
              },
              child: Text(playlistToEdit == null ? '创建' : '保存'),
            ),
          ],
        );
      },
    );
  }

  void _showDeletePlaylistDialog(Playlist playlist) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除歌单'),
          content: Text('确定要删除歌单 "${playlist.name}" 吗？此操作不可撤销。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Provider.of<MusicProvider>(context, listen: false).deletePlaylist(playlist.id);
                Navigator.of(context).pop();
                if (_selectedPlaylist?.id == playlist.id) {
                  setState(() {
                    _selectedPlaylist = null;
                  });
                }
              },
              child: const Text('删除', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateAndAddSongs(BuildContext context, Playlist playlist) async {
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    final List<String>? selectedSongIds = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AddSongsScreen(playlist: playlist),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
      ),
    );

    if (selectedSongIds != null && selectedSongIds.isNotEmpty) {
      await musicProvider.addSongsToPlaylist(playlist.id, selectedSongIds);
      if (_selectedPlaylist != null && _selectedPlaylist!.id == playlist.id) {
        setState(() {
          final updatedPlaylist = musicProvider.playlists.firstWhere((p) => p.id == playlist.id, orElse: () => playlist);
          _selectedPlaylist = updatedPlaylist;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已将歌曲添加到 "${playlist.name}"')),
      );
    }
  }

  Widget _buildPlaylistListView(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final playlists = musicProvider.playlists;

    return Scaffold(
      key: _PlaylistManagementScreenState.playlistListScaffoldKey, // Assign the key here
      appBar: AppBar(
        title: const Text('我的歌单'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: playlists.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '还没有歌单，快去创建一个吧！',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return PlaylistCardItem(
                    playlist: playlist,
                    musicProvider: musicProvider,
                    onTap: () {
                      setState(() {
                        _selectedPlaylist = playlist;
                      });
                    },
                    onPlay: () {
                      if (playlist.songIds.isNotEmpty) {
                        musicProvider.playPlaylist(playlist);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('开始播放歌单: ${playlist.name}')),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('歌单 "${playlist.name}" 为空。')),
                        );
                      }
                    },
                    onShowMenu: (itemContext) {
                      _showPlaylistMenu(itemContext, playlist, musicProvider);
                    });
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePlaylistDialog(),
        icon: const Icon(Icons.add),
        label: const Text("创建歌单"),
      ),
    );
  }

  void _showPlaylistMenu(BuildContext itemContext, Playlist playlist, MusicProvider musicProvider) {
    showModalBottomSheet(
      context: itemContext,
      builder: (bottomSheetBuildContext) => Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: const Text('播放歌单'),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              if (playlist.songIds.isNotEmpty) {
                musicProvider.playPlaylist(playlist);
                ScaffoldMessenger.of(itemContext).showSnackBar(
                  SnackBar(content: Text('开始播放歌单: ${playlist.name}')),
                );
              } else {
                ScaffoldMessenger.of(itemContext).showSnackBar(
                  SnackBar(content: Text('歌单 "${playlist.name}" 为空。')),
                );
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('重命名歌单'),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              _showCreatePlaylistDialog(playlistToEdit: playlist);
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add_outlined),
            title: const Text('添加歌曲到歌单'),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              _navigateAndAddSongs(itemContext, playlist);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('删除歌单', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(bottomSheetBuildContext);
              _showDeletePlaylistDialog(playlist);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistDetailView(BuildContext context, Playlist playlist) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final currentPlaylist = musicProvider.playlists.firstWhere((p) => p.id == playlist.id, orElse: () => playlist);
    final songsInPlaylist = musicProvider.songs.where((s) => currentPlaylist.songIds.contains(s.id)).toList();

    songsInPlaylist.sort((a, b) => currentPlaylist.songIds.indexOf(a.id).compareTo(currentPlaylist.songIds.indexOf(b.id)));

    return Scaffold(
      key: ValueKey('playlist_detail_scaffold_${playlist.id}'),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            setState(() {
              _selectedPlaylist = null;
              _isMultiSelectMode = false;
              _selectedSongIds.clear();
            });
          },
        ),
        title: Text(currentPlaylist.name),
        actions: [
          if (!_isMultiSelectMode)
            IconButton(
              icon: const Icon(Icons.select_all_outlined),
              tooltip: '批量管理',
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = true;
                  _selectedSongIds.clear();
                });
              },
            ),
          if (_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '退出批量管理',
              onPressed: () {
                setState(() {
                  _isMultiSelectMode = false;
                  _selectedSongIds.clear();
                });
              },
            ),
            SizedBox(
              width: 15,
            ),
          ],
          if (!_isMultiSelectMode) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: '重命名歌单',
              onPressed: () => _showCreatePlaylistDialog(playlistToEdit: currentPlaylist),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: '删除歌单',
              onPressed: () => _showDeletePlaylistDialog(currentPlaylist),
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow_outlined),
              tooltip: '播放全部',
              onPressed: () {
                if (songsInPlaylist.isNotEmpty) {
                  musicProvider.playPlaylist(currentPlaylist);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('开始播放歌单: ${currentPlaylist.name}')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('歌单 "${currentPlaylist.name}" 为空。')),
                  );
                }
              },
            ),
            SizedBox(
              width: 15,
            ),
          ]
        ],
      ),
      body: songsInPlaylist.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_off_outlined, size: 70, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('歌单中还没有歌曲', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('添加歌曲'),
                    onPressed: () => _navigateAndAddSongs(context, currentPlaylist),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: songsInPlaylist.length,
              itemBuilder: (context, index) {
                final song = songsInPlaylist[index];
                final isSelected = _selectedSongIds.contains(song.id);
                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    if (_isMultiSelectMode)
                      Positioned(
                        left: 0,
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (checked) {
                            setState(() {
                              if (checked == true) {
                                _selectedSongIds.add(song.id);
                              } else {
                                _selectedSongIds.remove(song.id);
                              }
                            });
                          },
                        ),
                      ),
                    Container(
                      margin: EdgeInsets.only(left: _isMultiSelectMode ? 48 : 0),
                      child: PlaylistSongCardItem(
                        song: song,
                        playlist: currentPlaylist,
                        musicProvider: musicProvider,
                        onPlay: _isMultiSelectMode
                            ? null
                            : () {
                                int originalIndex = musicProvider.songs.indexWhere((s) => s.id == song.id);
                                musicProvider.playSong(song, index: originalIndex != -1 ? originalIndex : null);
                              },
                        onRemove: _isMultiSelectMode
                            ? null
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    title: Text(
                                      '移除歌曲',
                                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                                    ),
                                    content: Text('确定要从歌单 "${currentPlaylist.name}" 中移除歌曲 "${song.title}" 吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(dialogContext, false),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(dialogContext, true),
                                        child: const Text('移除'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  await musicProvider.removeSongFromPlaylist(currentPlaylist.id, song.id);
                                  setState(() {
                                    _selectedPlaylist =
                                        musicProvider.playlists.firstWhere((p) => p.id == currentPlaylist.id, orElse: () => currentPlaylist);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('已从歌单中移除 "${song.title}"')),
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: _isMultiSelectMode
          ? FloatingActionButton.extended(
              onPressed: _selectedSongIds.isEmpty
                  ? null
                  : () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: Text(
                            '批量移除歌曲',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                          ),
                          content: Text('确定要从歌单 "${currentPlaylist.name}" 中移除所选的 ${_selectedSongIds.length} 首歌曲吗？'),
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
                        for (final songId in _selectedSongIds) {
                          await musicProvider.removeSongFromPlaylist(currentPlaylist.id, songId);
                        }
                        setState(() {
                          _selectedPlaylist = musicProvider.playlists.firstWhere((p) => p.id == currentPlaylist.id, orElse: () => currentPlaylist);
                          _selectedSongIds.clear();
                          _isMultiSelectMode = false;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已批量移除所选歌曲')),
                        );
                      }
                    },
              label: Text('删除所选 (${_selectedSongIds.length})'),
              icon: const Icon(Icons.delete_outline),
              backgroundColor: _selectedSongIds.isEmpty ? Colors.grey : Colors.redAccent,
            )
          : FloatingActionButton.extended(
              onPressed: () => _navigateAndAddSongs(context, currentPlaylist),
              label: const Text('添加歌曲'),
              icon: const Icon(Icons.add_circle_outline),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget currentChild;
    if (_selectedPlaylist == null) {
      currentChild = _buildPlaylistListView(context);
    } else {
      currentChild = _buildPlaylistDetailView(context, _selectedPlaylist!);
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        // final Key? key = child.key; // No longer needed for this animation type

        // New child starts from the bottom of the screen.
        const Offset tweenStartOffset = Offset(0.0, 1.0);
        // Common target offset for both views when they are centered.
        const Offset tweenEndOffset = Offset.zero;

        // The Tween defines the path from an off-screen position (tweenStartOffset)
        // to the center position (tweenEndOffset).
        // The 'animation' object provided by AnimatedSwitcher goes:
        // - 0.0 to 1.0 for the new child entering.
        // - 1.0 to 0.0 for the old child exiting.
        // So, tween.animate(curvedAnimation) will correctly map these ranges:
        // - Entering: maps 0->1 to tweenStartOffset -> tweenEndOffset (slides up).
        // - Exiting: maps 1->0 to tweenEndOffset -> tweenStartOffset (slides down).
        final tween = Tween<Offset>(begin: tweenStartOffset, end: tweenEndOffset);

        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOut,
        );

        return SlideTransition(
          position: tween.animate(curvedAnimation),
          child: child,
        );
      },
      child: currentChild,
    );
  }
}

// New PlaylistCardItem Widget
class PlaylistCardItem extends StatelessWidget {
  final Playlist playlist;
  final MusicProvider musicProvider;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final Function(BuildContext) onShowMenu;

  const PlaylistCardItem({
    super.key,
    required this.playlist,
    required this.musicProvider,
    this.onTap,
    this.onPlay,
    required this.onShowMenu,
  });

  @override
  Widget build(BuildContext context) {
    // Attempt to get the album art of the first song in the playlist
    // This is a simple approach; more sophisticated logic might be desired
    // (e.g., a specific playlist cover image, or a collage of song arts)
    Song? firstSongWithArt;
    if (playlist.songIds.isNotEmpty) {
      final firstSongId = playlist.songIds.first;
      try {
        // Add try-catch in case song is not found in main songs list
        final song = musicProvider.songs.firstWhere((s) => s.id == firstSongId);
        if (song.albumArt != null) {
          firstSongWithArt = song;
        }
      } catch (e) {
        // Song not found or other error, firstSongWithArt remains null
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      elevation: 4.0,
      shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: firstSongWithArt?.albumArt != null
                    ? Image.memory(
                        firstSongWithArt!.albumArt!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderIcon(context, size: 60),
                      )
                    : _buildPlaceholderIcon(context, size: 60),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      playlist.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.songIds.length} 首歌曲',
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (playlist.songIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.play_circle_filled_outlined),
                  iconSize: 30,
                  tooltip: '播放歌单',
                  color: Theme.of(context).colorScheme.primary,
                  onPressed: onPlay,
                ),
              IconButton(
                icon: const Icon(Icons.more_vert_outlined),
                tooltip: '更多选项',
                onPressed: () => onShowMenu(context), // Pass context for the modal sheet
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderIcon(BuildContext context, {double size = 60}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        size: size * 0.6,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
  }
}

// New PlaylistSongCardItem Widget
class PlaylistSongCardItem extends StatelessWidget {
  final Song song;
  final Playlist playlist; // Added playlist to know the context if needed for menu, etc.
  final MusicProvider musicProvider;
  final VoidCallback? onPlay;
  final VoidCallback? onRemove;
  // final Function(BuildContext) onShowMenu; // Optional: if more actions are needed per song

  const PlaylistSongCardItem({
    super.key,
    required this.song,
    required this.playlist,
    required this.musicProvider,
    this.onPlay,
    this.onRemove,
    // required this.onShowMenu,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final bool isCurrentlyPlaying = musicProvider.currentSong?.id == song.id && musicProvider.isPlaying;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: InkWell(
        onTap: onPlay, // Play song on tap
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: song.albumArt != null
                    ? Image.memory(
                        song.albumArt!,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => _buildPlaceholderAlbumArt(context, size: 50),
                      )
                    : _buildPlaceholderAlbumArt(context, size: 50),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isCurrentlyPlaying ? Theme.of(context).colorScheme.primary : null,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isCurrentlyPlaying)
                MusicWaveform(
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              const SizedBox(width: 8),
              Text(
                _formatDuration(song.duration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                tooltip: '从歌单移除',
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderAlbumArt(BuildContext context, {double size = 50}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Icon(
        Icons.music_note_rounded,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

// Make sure MusicProvider has createPlaylist, renamePlaylist, deletePlaylist,
// addSongsToPlaylist, and removeSongFromPlaylist methods.
// Example for removeSongFromPlaylist (add to MusicProvider if not present):
/*
// In MusicProvider:
Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
  final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
  if (playlistIndex != -1) {
    _playlists[playlistIndex].songIds.remove(songId);
    await _databaseService.updatePlaylist(_playlists[playlistIndex]); // Assuming updatePlaylist handles song ID list changes
    // Or a more specific DB method: await _databaseService.removeSongFromPlaylist(playlistId, songId);
    notifyListeners();
  }
}
*/

// Ensure AddSongsScreen is correctly implemented and can return List<String> of song IDs.
// It should take the playlist and existing song IDs as parameters.
// Example signature for AddSongsScreen constructor:
// const AddSongsScreen({super.key, required this.playlist, required this.existingSongIds});
