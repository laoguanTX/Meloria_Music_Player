// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist.dart';
import '../providers/music_provider.dart';

class AddSongsScreen extends StatefulWidget {
  final Playlist playlist;

  const AddSongsScreen({super.key, required this.playlist});

  @override
  State<AddSongsScreen> createState() => _AddSongsScreenState();
}

class _AddSongsScreenState extends State<AddSongsScreen> {
  final List<String> _selectedSongIds = [];

  @override
  Widget build(BuildContext context) {
    final musicProvider = Provider.of<MusicProvider>(context);
    // Filter out songs already in the playlist
    final availableSongs = musicProvider.songs.where((song) => !widget.playlist.songIds.contains(song.id)).toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('添加到 "${widget.playlist.name}"', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: Text('完成 (${_selectedSongIds.length})'),
              onPressed: _selectedSongIds.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop(_selectedSongIds);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ).copyWith(
                elevation: MaterialStateProperty.all(0), // No shadow for a cleaner look
              ),
            ),
          )
        ],
        elevation: 1, // Subtle shadow for AppBar
        backgroundColor: theme.colorScheme.surface, // Use surface color for AppBar
        foregroundColor: theme.colorScheme.onSurface, // Adjust AppBar text/icon color
      ),
      body: availableSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off_outlined, size: 60, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                  const SizedBox(height: 16),
                  Text(
                    '没有可添加的歌曲。',
                    style: TextStyle(fontSize: 16, color: theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              itemCount: availableSongs.length,
              separatorBuilder: (context, index) => Divider(height: 1, indent: 70, endIndent: 16, color: theme.dividerColor.withOpacity(0.5)),
              itemBuilder: (context, index) {
                final song = availableSongs[index];
                final isSelected = _selectedSongIds.contains(song.id);

                Widget leadingWidget;
                if (song.albumArt != null && song.albumArt!.isNotEmpty) {
                  leadingWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(4.0),
                    child: Image.memory(
                      song.albumArt!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.music_note, size: 30),
                    ),
                  );
                } else {
                  leadingWidget = CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                    child: Icon(Icons.music_note, size: 24, color: theme.colorScheme.onSecondaryContainer),
                  );
                }

                return Material(
                  // Wrap with Material for InkWell splash effect on colored background
                  color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.3) : Colors.transparent,
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedSongIds.add(song.id);
                        } else {
                          _selectedSongIds.remove(song.id);
                        }
                      });
                    },
                    secondary: leadingWidget, // Use secondary for leading to align with CheckboxListTile structure
                    title: Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface),
                    ),
                    subtitle: Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    activeColor: theme.colorScheme.primary,
                    checkboxShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    // onTap handled by onChanged of CheckboxListTile
                  ),
                );
              },
            ),
    );
  }
}
