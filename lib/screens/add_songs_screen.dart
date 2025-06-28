// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';
import '../models/song.dart'; // Import Song model

class AddSongsScreen extends StatefulWidget {
  final Playlist playlist;

  const AddSongsScreen({super.key, required this.playlist});

  @override
  State<AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends State<AddSongsScreen> {
  final List<String> _selectedSongIds = [];
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    final theme = Theme.of(context);

    // Filter out songs already in the playlist and apply search query
    final availableSongs = musicProvider.songs.where((song) {
      final notInPlaylist = !widget.playlist.songIds.contains(song.id);
      if (_searchQuery.isEmpty) {
        return notInPlaylist;
      }
      final query = _searchQuery.toLowerCase();
      return notInPlaylist &&
          (song.title.toLowerCase().contains(query) || song.artist.toLowerCase().contains(query) || song.album.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('添加到 "${widget.playlist.name}"'),
        elevation: 0,
        // backgroundColor: theme.colorScheme.primary,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: '搜索歌曲、艺术家、专辑...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30.0),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 20),
              ),
            ),
          ),
          Expanded(
            child: availableSongs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off_rounded, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? '没有可添加的歌曲' : '未找到匹配的歌曲',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: availableSongs.length,
                    itemBuilder: (context, index) {
                      final song = availableSongs[index];
                      final isSelected = _selectedSongIds.contains(song.id);
                      return AddSongCardItem(
                        song: song,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedSongIds.remove(song.id);
                            } else {
                              _selectedSongIds.add(song.id);
                            }
                          });
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _selectedSongIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pop(_selectedSongIds);
              },
              label: Text('完成 (${_selectedSongIds.length})'),
              icon: const Icon(Icons.check_circle_outline),
            )
          : null,
    );
  }
}

// A new card item for the AddSongsScreen for better UI
class AddSongCardItem extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final VoidCallback onTap;

  const AddSongCardItem({
    super.key,
    required this.song,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: isSelected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Stack(
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
                          )
                        : _buildPlaceholderAlbumArt(context, size: 50),
                  ),
                  if (isSelected)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
