import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:file_picker/file_picker.dart' as fp; // Aliased file_picker
import 'package:permission_handler/permission_handler.dart';
// import 'package:audio_metadata_reader/audio_metadata_reader.dart'; // Commented out or remove if not used elsewhere for reading
import 'package:flutter_taggy/flutter_taggy.dart'; // Added for flutter_taggy
import '../models/song.dart';
import '../models/lyric_line.dart'; // Added import for LyricLine
import '../services/database_service.dart';
import 'theme_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart'; // Required for kIsWeb

enum PlayerState { stopped, playing, paused }

enum RepeatMode { none, one, all }

class MusicProvider with ChangeNotifier {
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();
  ThemeProvider? _themeProvider; // 添加主题提供器引用

  List<Song> _songs = [];
  List<Playlist> _playlists = [];
  List<MusicFolder> _folders = [];
  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  RepeatMode _repeatMode = RepeatMode.none;
  bool _shuffleMode = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _currentIndex = 0;
  double _volume = 1.0; // 添加音量控制变量
  double _volumeBeforeMute = 0.7; // 记录静音前的音量
  bool _isGridView = false; // 添加视图模式状态，默认为列表视图

  List<LyricLine> _lyrics = [];
  List<LyricLine> get lyrics => _lyrics;
  int _currentLyricIndex = -1;
  int get currentLyricIndex => _currentLyricIndex;

  // Getters
  List<Song> get songs => _songs;
  List<Playlist> get playlists => _playlists;
  List<MusicFolder> get folders => _folders;
  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  RepeatMode get repeatMode => _repeatMode;
  bool get shuffleMode => _shuffleMode;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _playerState == PlayerState.playing;
  double get volume => _volume; // 添加音量getter
  bool get isGridView => _isGridView; // 添加视图模式getter
  MusicProvider() {
    _initAudioPlayer();
    _loadSongs();
  }

  // 获取不重复的专辑列表
  List<String> getUniqueAlbums() {
    if (_songs.isEmpty) {
      return [];
    }
    final albumSet = <String>{};
    for (var song in _songs) {
      if (song.album.isNotEmpty) {
        albumSet.add(song.album);
      }
    }
    return albumSet.toList();
  }

  // 获取不重复的艺术家列表
  List<String> getUniqueArtists() {
    if (_songs.isEmpty) {
      return [];
    }
    final artistSet = <String>{};
    for (var song in _songs) {
      if (song.artist.isNotEmpty) {
        artistSet.add(song.artist);
      }
    }
    return artistSet.toList();
  }

  // 获取歌曲总时长
  Duration getTotalDurationOfSongs() {
    if (_songs.isEmpty) {
      return Duration.zero;
    }
    Duration totalDuration = Duration.zero;
    for (var song in _songs) {
      totalDuration += song.duration;
    }
    return totalDuration;
  }

  // 获取最常播放的歌曲列表 (需要播放历史记录功能)
  // 注意: 当前没有播放历史记录功能，如果需要此功能，需要先实现
  List<Song> getMostPlayedSongs({int count = 5}) {
    if (_songs.isEmpty) {
      return [];
    }
    // Sort songs by playCount in descending order
    List<Song> sortedSongs = List.from(_songs);
    sortedSongs.sort((a, b) => b.playCount.compareTo(a.playCount));

    // Take the top 'count' songs
    return sortedSongs.take(count).toList();
  }

  // 设置主题提供器引用
  void setThemeProvider(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  void _initAudioPlayer() {
    // 设置初始音量
    _audioPlayer.setVolume(_volume);

    _audioPlayer.onDurationChanged.listen((duration) {
      _totalDuration = duration;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      if (_currentSong != null && _currentSong!.hasLyrics) {
        updateLyric(position); // Moved updateLyric call here
      }
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      _onSongComplete();
    });
    _audioPlayer.onPlayerStateChanged.listen((audio.PlayerState state) {
      switch (state) {
        case audio.PlayerState.playing:
          _playerState = PlayerState.playing;
          break;
        case audio.PlayerState.paused:
          _playerState = PlayerState.paused;
          break;
        case audio.PlayerState.stopped:
          _playerState = PlayerState.stopped;
          break;
        case audio.PlayerState.completed:
          _playerState = PlayerState.stopped;
          break;
        default:
          break;
      }
      notifyListeners();
    });
  }

  Future<void> _loadSongs() async {
    _songs = await _databaseService.getAllSongs();
    _playlists = await _databaseService.getAllPlaylists();
    _folders = await _databaseService.getAllFolders();
    notifyListeners();
  }

  Future<void> importMusic() async {
    if (await _requestPermission()) {
      try {
        fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
          type: fp.FileType.custom, // Use aliased FileType
          allowedExtensions: ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma'],
          allowMultiple: true,
        );

        if (result != null) {
          for (var file in result.files) {
            if (file.path != null) {
              await _addSongToLibrary(file.path!);
            }
          }
          await _loadSongs();
        }
      } catch (e) {
        // Error importing music: $e
      }
    }
  }

  Future<bool> _requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    return status.isGranted;
  }

  Future<void> _addSongToLibrary(String filePath) async {
    // Removed playlistName parameter
    File file = File(filePath);
    String fileName = file.uri.pathSegments.last;
    String fileExtension = fileName.split('.').last.toLowerCase();

    // 检查文件是否为支持的音频格式
    List<String> supportedFormats = [
      'mp3',
      'flac',
      'wav',
      'aac',
      'm4a',
      'ogg',
      'wma'
    ];
    if (!supportedFormats.contains(fileExtension)) {
      // 不支持的音频格式: $fileExtension for file $filePath
      return;
    }

    String title = '';
    String artist = '';
    String album = 'Unknown Album';
    Uint8List? albumArtData;
    bool hasLyrics = false;
    String? embeddedLyrics;
    Duration songDuration = Duration.zero;

    try {
      // Read metadata using flutter_taggy
      final TaggyFile taggyFile = await Taggy.readPrimary(filePath);

      if (taggyFile.firstTagIfAny != null) {
        final tag = taggyFile.firstTagIfAny!;
        title = tag.trackTitle ?? '';
        artist = tag.trackArtist ?? '';
        album = tag.album ?? 'Unknown Album';
        if (tag.pictures.isNotEmpty) {
          albumArtData = tag.pictures.first.picData; // Corrected to use picData
        }
        songDuration = taggyFile.duration;
        embeddedLyrics = tag.lyrics;
        if (embeddedLyrics != null && embeddedLyrics.isNotEmpty) {
          hasLyrics = true;
          // Found embedded lyrics for $filePath
        }
      }

      // Fallback for title and artist if not found in metadata
      if (title.isEmpty) {
        final titleAndArtist = _extractTitleAndArtist(
            filePath, null); // Pass null as metadata as taggy handles it
        title = titleAndArtist['title']!;
        artist = titleAndArtist['artist']!;
      }
      if (title.isEmpty) {
        title = fileName.substring(0, fileName.lastIndexOf('.'));
      }

      // LRC Check (only if embedded lyrics were not found)
      if (!hasLyrics) {
        try {
          String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
          File lrcFile = File(lrcFilePath);
          if (await lrcFile.exists()) {
            hasLyrics = true;
            // Found .lrc file for $filePath
          }
        } catch (e) {
          // Error checking for LRC file for $filePath: $e
          // hasLyrics remains false
        }
      }

      Song song = Song(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        artist: artist,
        album: album,
        filePath: filePath,
        duration: songDuration,
        albumArt: albumArtData,
        hasLyrics: hasLyrics,
        embeddedLyrics: embeddedLyrics,
      );

      await _databaseService.insertSong(song);
      // Successfully added song via _addSongToLibrary: $title // Optional for debugging
    } catch (e) {
      // Failed to add song $filePath to library via _addSongToLibrary: $e
      // Fallback if flutter_taggy fails
      final titleAndArtist = _extractTitleAndArtist(filePath, null);
      title = titleAndArtist['title']!;
      artist = titleAndArtist['artist']!;
      if (title.isEmpty) {
        title = fileName.substring(0, fileName.lastIndexOf('.'));
      }
      // LRC Check (only if embedded lyrics were not found)
      if (!hasLyrics) {
        // Check again in case of error
        try {
          String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
          File lrcFile = File(lrcFilePath);
          if (await lrcFile.exists()) {
            hasLyrics = true;
            // Found .lrc file for $filePath (after error)
          }
        } catch (eLrc) {
          // Error checking for LRC file for $filePath (after error): $eLrc
        }
      }
      Song song = Song(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        artist: artist,
        album: 'Unknown Album', // Default album on error
        filePath: filePath,
        duration: Duration.zero, // Default duration on error
        albumArt: null, // No album art on error
        hasLyrics: hasLyrics, // Use hasLyrics status from LRC check
        embeddedLyrics: null, // No embedded lyrics on error
      );
      await _databaseService.insertSong(song);
    }
  }

  Future<void> playSong(Song song, {int? index}) async {
    try {
      // Increment play count before setting current song,
      // so the UI can potentially update if it's already showing this song's stats.
      song.playCount++;
      await _databaseService.incrementPlayCount(song.id);

      // Update the song in the local list as well
      final songIndexInList = _songs.indexWhere((s) => s.id == song.id);
      if (songIndexInList != -1) {
        _songs[songIndexInList] = song;
      }

      _currentSong = song;
      _currentIndex = index ?? _songs.indexOf(song);

      // 播放歌曲: ${song.title}
      // 专辑图片数据: ${song.albumArt != null ? '${song.albumArt!.length} bytes' : '无'}

      // 更新主题颜色
      if (_themeProvider != null) {
        await _themeProvider!.updateThemeFromAlbumArt(song.albumArt);
      }

      await _audioPlayer.play(audio.DeviceFileSource(song.filePath));
      _playerState = PlayerState.playing;

      if (_currentSong != null) {
        await loadLyrics(_currentSong!);
      }

      notifyListeners();
    } catch (e) {
      // Error playing song: $e
    }
  }

  Future<void> playPause() async {
    if (_playerState == PlayerState.playing) {
      await _audioPlayer.pause();
      _playerState = PlayerState.paused;
    } else if (_playerState == PlayerState.paused) {
      await _audioPlayer.resume();
      _playerState = PlayerState.playing;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _playerState = PlayerState.stopped;
    _currentPosition = Duration.zero;
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _audioPlayer.seek(position);
  }

  // 音量控制方法
  Future<void> setVolume(double volume) async {
    double newVolume = volume.clamp(0.0, 1.0);
    // 如果设置的不是0音量，记录这个音量作为"静音前音量"
    if (newVolume > 0) {
      _volumeBeforeMute = newVolume;
    }
    _volume = newVolume;
    await _audioPlayer.setVolume(_volume);
    notifyListeners();
  }

  // 切换静音状态
  Future<void> toggleMute() async {
    if (_volume > 0) {
      // 当前有音量，静音
      _volumeBeforeMute = _volume;
      await setVolume(0.0);
    } else {
      // 当前静音，恢复音量
      await setVolume(_volumeBeforeMute);
    }
  }

  Future<void> increaseVolume() async {
    double newVolume = (_volume + 0.1).clamp(0.0, 1.0);
    await setVolume(newVolume);
  }

  Future<void> decreaseVolume() async {
    double newVolume = (_volume - 0.1).clamp(0.0, 1.0);
    await setVolume(newVolume);
  }

  Future<void> nextSong() async {
    if (_songs.isEmpty) return;

    if (_shuffleMode) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch % _songs.length);
    } else {
      _currentIndex = (_currentIndex + 1) % _songs.length;
    }

    await playSong(_songs[_currentIndex], index: _currentIndex);
  }

  Future<void> previousSong() async {
    if (_songs.isEmpty) return;

    if (_shuffleMode) {
      _currentIndex = (DateTime.now().millisecondsSinceEpoch % _songs.length);
    } else {
      _currentIndex = (_currentIndex - 1 + _songs.length) % _songs.length;
    }

    await playSong(_songs[_currentIndex], index: _currentIndex);
  }

  void _onSongComplete() {
    switch (_repeatMode) {
      case RepeatMode.one:
        playSong(_currentSong!, index: _currentIndex);
        break;
      case RepeatMode.all:
        nextSong();
        break;
      case RepeatMode.none:
        if (_currentIndex < _songs.length - 1) {
          nextSong();
        } else {
          stop();
        }
        break;
    }
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.none:
        _repeatMode = RepeatMode.all;
        break;
      case RepeatMode.all:
        _repeatMode = RepeatMode.one;
        break;
      case RepeatMode.one:
        _repeatMode = RepeatMode.none;
        break;
    }
    notifyListeners();
  }

  void toggleShuffle() {
    _shuffleMode = !_shuffleMode;
    notifyListeners();
  }

  // 切换视图模式（网格视图 / 列表视图）
  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  // 删除歌曲功能
  Future<bool> deleteSong(String songId) async {
    try {
      // 从数据库中删除
      await _databaseService.deleteSong(songId);
      // 从本地列表中删除
      final songIndex = _songs.indexWhere((song) => song.id == songId);
      if (songIndex != -1) {
        _songs.removeAt(songIndex);

        // 如果删除的是当前播放的歌曲
        if (_currentSong?.id == songId) {
          await stop();
          _currentSong = null;
          _currentIndex = 0;
        } else if (_currentSong != null && songIndex < _currentIndex) {
          // 如果删除的歌曲在当前播放歌曲之前，调整索引
          _currentIndex--;
        }

        // 如果删除后列表为空，重置播放状态
        if (_songs.isEmpty) {
          await stop();
          _currentSong = null;
          _currentIndex = 0;
        } else if (_currentIndex >= _songs.length) {
          _currentIndex = _songs.length - 1;
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // 删除歌曲时出错: $e
      return false;
    }
  }

  // 批量删除歌曲
  Future<bool> deleteSongs(List<String> songIds) async {
    try {
      for (String songId in songIds) {
        await _databaseService.deleteSong(songId);
      }
      _songs.removeWhere((song) => songIds.contains(song.id));
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 获取音乐库统计信息
  Future<Map<String, int>> getLibraryStats() async {
    final songCount = await _databaseService.getSongCount();
    final playlistCount = _playlists.length;

    // 统计不同格式的文件数量
    int flacCount = 0;
    int wavCount = 0;
    int mp3Count = 0;
    int otherCount = 0;

    for (Song song in _songs) {
      String extension = song.filePath.toLowerCase().split('.').last;
      switch (extension) {
        case 'flac':
          flacCount++;
          break;
        case 'wav':
          wavCount++;
          break;
        case 'mp3':
          mp3Count++;
          break;
        default:
          otherCount++;
          break;
      }
    }

    return {
      'total': songCount,
      'playlists': playlistCount,
      'flac': flacCount,
      'wav': wavCount,
      'mp3': mp3Count,
      'other': otherCount,
    };
  }

  // 清理数据库
  Future<void> cleanupDatabase() async {
    await _databaseService.cleanupPlaylistSongs();
    await _loadSongs(); // 重新加载数据
  }

  // 刷新音乐库
  Future<void> refreshLibrary() async {
    await _loadSongs();
  }

  // 播放列表管理方法
  Future<void> createPlaylist(String name) async {
    final playlist = Playlist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      songs: [],
      createdAt: DateTime.now(),
    );

    await _databaseService.insertPlaylist(playlist);
    _playlists.add(playlist);
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _databaseService.deletePlaylist(playlistId);
    _playlists.removeWhere((playlist) => playlist.id == playlistId);
    notifyListeners();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final updatedPlaylist = Playlist(
        id: _playlists[playlistIndex].id,
        name: newName,
        songs: _playlists[playlistIndex].songs,
        createdAt: _playlists[playlistIndex].createdAt,
      );

      await _databaseService.insertPlaylist(updatedPlaylist);
      _playlists[playlistIndex] = updatedPlaylist;
      notifyListeners();
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final playlist = _playlists[playlistIndex];
      if (!playlist.songs.any((s) => s.id == song.id)) {
        final updatedSongs = [...playlist.songs, song];
        final updatedPlaylist = Playlist(
          id: playlist.id,
          name: playlist.name,
          songs: updatedSongs,
          createdAt: playlist.createdAt,
        );

        await _databaseService.insertPlaylist(updatedPlaylist);
        _playlists[playlistIndex] = updatedPlaylist;
        notifyListeners();
      }
    }
  }

  Future<void> playPlaylist(String playlistId) async {
    final playlist = _playlists.firstWhere((p) => p.id == playlistId);
    if (playlist.songs.isNotEmpty) {
      _songs = playlist.songs;
      _currentIndex = 0;
      await playSong(playlist.songs.first);
    }
  }

  // 歌曲排序方法
  void sortSongs(String sortBy) {
    switch (sortBy) {
      case 'title':
        _songs.sort((a, b) => a.title.compareTo(b.title));
        break;
      case 'artist':
        _songs.sort((a, b) => a.artist.compareTo(b.artist));
        break;
      case 'album':
        _songs.sort((a, b) => a.album.compareTo(b.album));
        break;
      case 'duration':
        _songs.sort((a, b) => a.duration.compareTo(b.duration));
        break;
      default:
        _songs.sort((a, b) => a.title.compareTo(b.title));
    }
    notifyListeners();
  }

  // 更新歌曲信息
  Future<bool> updateSongInfo(Song updatedSong) async {
    try {
      // 在数据库中更新歌曲信息
      await _databaseService.updateSong(updatedSong);

      // 在本地列表中更新歌曲信息
      final songIndex = _songs.indexWhere((song) => song.id == updatedSong.id);
      if (songIndex != -1) {
        _songs[songIndex] = updatedSong;

        // 如果更新的是当前播放的歌曲，也要更新当前歌曲
        if (_currentSong?.id == updatedSong.id) {
          _currentSong = updatedSong;
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      // 更新歌曲信息时出错: $e
      return false;
    }
  }

  // 智能解析文件名中的元数据信息
  Map<String, String> _parseMetadataFromFilename(String filename) {
    String title = filename;
    String artist = '';

    // 保持原始文件名，不移除任何信息，只是用于分析
    String workingFilename = filename.trim();

    // 如果文件名包含"标题 - 艺术家"格式的分隔符
    List<String> separators = [' - ', ' – ', ' — ', ' | ', '_'];

    for (String separator in separators) {
      if (workingFilename.contains(separator)) {
        List<String> parts = workingFilename.split(separator);
        if (parts.length >= 2) {
          String part1 = parts[0].trim();
          String part2 =
              parts[1].trim(); // 只有当数字后面跟着点号和空格时（如 "01. "），才认为是曲目编号并去掉
          String cleanPart1 = part1;
          if (RegExp(r'^\d+\.\s+').hasMatch(part1)) {
            cleanPart1 = part1.replaceAll(RegExp(r'^\d+\.\s+'), '').trim();
          }

          // 如果去掉曲目编号后还有内容，使用清理后的内容
          if (cleanPart1.isNotEmpty && cleanPart1 != part1) {
            title = cleanPart1;
            artist = part2;
          }
          // 如果第一部分看起来像艺术家名（较短且无空格），使用 "艺术家 - 标题" 格式
          else if (part1.length < part2.length * 0.6 && !part1.contains(' ')) {
            artist = part1;
            title = part2;
          }
          // 默认使用 "标题 - 艺术家" 格式
          else {
            title = part1;
            artist = part2;
          }
          break;
        }
      }
    }

    // 如果没有找到分隔符，但包含括号或方括号，尝试提取艺术家信息
    if (artist.isEmpty && title == filename) {
      // 尝试匹配 "标题 [艺术家]" 或 "标题 (艺术家)" 格式
      RegExp bracketPattern =
          RegExp(r'^(.+?)\s*[\[\(]([^\[\]\(\)]+)[\]\)](.*)$');
      Match? match = bracketPattern.firstMatch(workingFilename);

      if (match != null) {
        String titlePart = match.group(1)?.trim() ?? '';
        String bracketContent = match.group(2)?.trim() ?? '';
        String remainingPart = match.group(3)?.trim() ?? '';

        // 如果括号内容看起来像艺术家名，提取它
        if (bracketContent.isNotEmpty && bracketContent.length > 1) {
          title =
              titlePart + (remainingPart.isNotEmpty ? ' $remainingPart' : '');
          artist = bracketContent;
        }
      }
    } // 清理标题和艺术家中的多余空格，但保留原始字符
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    artist = artist.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 如果解析后标题为空，使用原始文件名
    if (title.isEmpty) {
      title = filename;
    }

    return {
      'title': title,
      'artist': artist,
    };
  }

  // 选择文件夹路径
  Future<String?> getDirectoryPath() async {
    try {
      // 使用 FilePicker 选择文件夹
      String? selectedDirectory = await fp.FilePicker.platform
          .getDirectoryPath(); // Use aliased FilePicker
      return selectedDirectory;
    } catch (e) {
      throw Exception('选择文件夹失败: $e');
    }
  }

  // 文件夹管理方法
  Future<void> addMusicFolder() async {
    try {
      final selectedDirectory = await getDirectoryPath();
      if (selectedDirectory != null) {
        // 检查文件夹是否已存在
        final exists = await _databaseService.folderExists(selectedDirectory);
        if (exists) {
          throw Exception('该文件夹已经添加过了');
        }

        final folderId = DateTime.now().millisecondsSinceEpoch.toString();
        final folderName = path.basename(selectedDirectory);

        final folder = MusicFolder(
          id: folderId,
          name: folderName,
          path: selectedDirectory,
          isAutoScan: true,
          createdAt: DateTime.now(),
        );

        await _databaseService.insertFolder(folder);
        _folders = await _databaseService.getAllFolders();

        // 立即扫描该文件夹
        await scanFolderForMusic(folder);

        notifyListeners();
      }
    } catch (e) {
      throw Exception('添加文件夹失败: $e');
    }
  }

  Future<void> scanFolderForMusic(MusicFolder folder) async {
    try {
      final directory = Directory(folder.path);
      if (!directory.existsSync()) {
        throw Exception('文件夹不存在: ${folder.path}');
      }

      final musicFiles = <FileSystemEntity>[];
      final supportedExtensions = [
        '.mp3',
        '.m4a',
        '.aac',
        '.flac',
        '.wav',
        '.ogg'
      ];

      // 递归扫描文件夹
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(extension)) {
            musicFiles.add(entity);
          }
        }
      }

      // 批量处理音乐文件
      for (final file in musicFiles) {
        try {
          await _processMusicFile(File(file.path));
        } catch (e) {
          // 处理文件失败: ${file.path}, 错误: $e
          // 继续处理其他文件
        }
      }

      // 刷新歌曲列表
      _songs = await _databaseService.getAllSongs();
      notifyListeners();
    } catch (e) {
      throw Exception('扫描文件夹失败: $e');
    }
  }

  Future<void> _processMusicFile(File file) async {
    final filePath = file.path;
    // 使用文件路径的哈希码作为ID可能不是全局唯一的，特别是如果将来可能跨设备或会话。
    // 考虑使用更健壮的唯一ID生成策略，例如UUID，或者基于文件内容的哈希。
    // 但对于当前本地应用的上下文，hashCode可能足够。
    // final fileId = filePath.hashCode.toString();
    // 改用文件路径本身或其安全哈希作为ID，如果数据库支持长字符串ID
    // 或者，如果需要数字ID，可以考虑数据库自增ID，并将filePath作为唯一约束。
    // 这里我们暂时保留hashCode，但标记为潜在改进点。
    final String fileId = filePath; // 使用文件路径作为ID，确保唯一性

    // 检查歌曲是否已存在
    if (await _databaseService.songExists(fileId)) {
      return;
    }

    String title = '';
    String artist = '';
    String album = 'Unknown Album';
    Uint8List? albumArtData;
    bool hasLyrics = false;
    String? embeddedLyrics;
    Duration songDuration = Duration.zero;

    try {
      // Read metadata using flutter_taggy
      final TaggyFile taggyFile = await Taggy.readPrimary(filePath);

      if (taggyFile.firstTagIfAny != null) {
        final tag = taggyFile.firstTagIfAny!;
        title = tag.trackTitle ?? '';
        artist = tag.trackArtist ?? '';
        album = tag.album ?? 'Unknown Album';
        if (tag.pictures.isNotEmpty) {
          albumArtData = tag.pictures.first.picData;
        }
        songDuration = taggyFile.duration;
        embeddedLyrics = tag.lyrics;
        if (embeddedLyrics != null && embeddedLyrics.isNotEmpty) {
          hasLyrics = true;
          // Found embedded lyrics for $filePath in _processMusicFile
        }
      }

      // Fallback for title and artist if not found in metadata
      if (title.isEmpty) {
        final titleAndArtist =
            _extractTitleAndArtist(filePath, null); // Pass null as metadata
        title = titleAndArtist['title']!;
        artist = titleAndArtist['artist']!;
      }
      final String fileName = path.basename(filePath);
      if (title.isEmpty) {
        title = fileName.substring(
            0,
            fileName.lastIndexOf('.') > -1
                ? fileName.lastIndexOf('.')
                : fileName.length);
      }

      // 检查同名LRC文件 (only if embedded lyrics were not found)
      if (!hasLyrics) {
        String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          hasLyrics = true;
          // Found .lrc file for $filePath in _processMusicFile
        }
      }

      final song = Song(
        id: fileId,
        title: title,
        artist: artist,
        album: album,
        filePath: filePath,
        duration: songDuration,
        albumArt: albumArtData,
        hasLyrics: hasLyrics, // 设置歌词状态
        embeddedLyrics: embeddedLyrics,
      );

      await _databaseService.insertSong(song);
    } catch (e) {
      // 处理音乐文件元数据失败: $filePath, 错误: $e
      // 创建基本的歌曲信息
      final String fileName = path.basename(filePath);
      final titleAndArtist = _extractTitleAndArtist(filePath, null);
      title = titleAndArtist['title']!;
      artist = titleAndArtist['artist']!;
      if (title.isEmpty) {
        title = fileName.substring(
            0,
            fileName.lastIndexOf('.') > -1
                ? fileName.lastIndexOf('.')
                : fileName.length);
      }

      // 即使元数据读取失败，也检查LRC文件
      if (!hasLyrics) {
        String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          hasLyrics = true;
          // Found .lrc file for $filePath in _processMusicFile (after error)
        }
      }

      final song = Song(
        id: fileId,
        title: title,
        artist: artist,
        album: 'Unknown Album',
        filePath: filePath,
        duration: Duration.zero,
        albumArt: null,
        hasLyrics: hasLyrics,
        embeddedLyrics: null,
      );

      await _databaseService.insertSong(song);
    }
  }

  Future<void> removeMusicFolder(String folderId) async {
    try {
      await _databaseService.deleteFolder(folderId);
      _folders = await _databaseService.getAllFolders();
      notifyListeners();
    } catch (e) {
      throw Exception('删除文件夹失败: $e');
    }
  }

  Future<void> toggleFolderAutoScan(String folderId) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final updatedFolder = folder.copyWith(isAutoScan: !folder.isAutoScan);

      await _databaseService.updateFolder(updatedFolder);
      _folders = await _databaseService.getAllFolders();
      notifyListeners();
    } catch (e) {
      throw Exception('更新文件夹设置失败: $e');
    }
  }

  Future<void> rescanAllFolders() async {
    try {
      final autoScanFolders = _folders.where((f) => f.isAutoScan).toList();

      for (final folder in autoScanFolders) {
        await scanFolderForMusic(folder);
      }
    } catch (e) {
      throw Exception('重新扫描文件夹失败: $e');
    }
  }

  // 提取标题和艺术家信息的方法
  Map<String, String> _extractTitleAndArtist(
      String filePath, dynamic metadata) {
    String filename = path.basenameWithoutExtension(filePath);
    String title = '';
    String artist = '';

    if (metadata != null) {
      title = metadata.title ?? '';
      artist = metadata.artist ?? '';
    }

    // 如果标签信息不完整，尝试从文件名解析
    if (title.isEmpty || artist.isEmpty) {
      final parsed = _parseMetadataFromFilename(filename);
      if (title.isEmpty) title = parsed['title'] ?? filename;
      if (artist.isEmpty) artist = parsed['artist'] ?? '';
    }
    if (title.isEmpty) title = filename;

    return {
      'title': title,
      'artist': artist,
    };
  }

  Future<void> loadLyrics(Song song) async {
    // 优先使用内嵌歌词 (if available in the future)
    if (song.embeddedLyrics != null && song.embeddedLyrics!.isNotEmpty) {
      // print("Loading embedded lyrics for ${song.title}");
      _lyrics = _parseLrc(
          song.embeddedLyrics!); // Assuming embedded lyrics are in LRC format
      _currentLyricIndex = -1;
      notifyListeners();
      return;
    }

    // 如果没有内嵌歌词，或者内嵌歌词为空，则尝试加载LRC文件
    // song.hasLyrics would be true if an .lrc file was found OR if embeddedLyrics were successfully loaded (in the future)
    if (song.hasLyrics) {
      // print(
      //     "Loading .lrc file for ${song.title} as embeddedLyrics are not available or song.hasLyrics is true due to .lrc file");
      try {
        final lrcPath = '${path.withoutExtension(song.filePath)}.lrc';
        final file = File(lrcPath);
        if (await file.exists()) {
          final content = await file.readAsString();
          _lyrics = _parseLrc(content);
        } else {
          // This case should ideally not be hit if song.hasLyrics was true SOLELY due to an .lrc file,
          // but as a fallback, or if hasLyrics was true for embedded but embeddedLyrics is now null.
          _lyrics = [];
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error loading .lrc file lyrics: $e');
        }
        _lyrics = [];
      }
      _currentLyricIndex = -1;
      notifyListeners();
      return;
    }

    // 如果两种歌词都没有 (song.hasLyrics is false and embeddedLyrics is null/empty)
    _lyrics = [];
    _currentLyricIndex = -1;
    notifyListeners();
  }

  List<LyricLine> _parseLrc(String lrcContent) {
    final lines = <LyricLine>[];
    final regex = RegExp(
        r"\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)"); // Adjusted regex for milliseconds

    for (final line in lrcContent.split('\n')) {
      final matches = regex.firstMatch(line);
      if (matches != null) {
        final min = int.parse(matches.group(1)!);
        final sec = int.parse(matches.group(2)!);
        final msString = matches.group(3)!;
        final ms = msString.length == 3
            ? int.parse(msString)
            : int.parse(msString) * 10; // Handle 2 or 3 digit ms
        final text = matches.group(4)!.trim();
        if (text.isNotEmpty) {
          lines.add(LyricLine(
              Duration(minutes: min, seconds: sec, milliseconds: ms), text));
        }
      }
    }
    // Sort by timestamp as LRC files can have multiple timestamps for one line
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  void updateLyric(Duration position) {
    if (_lyrics.isEmpty) {
      if (_currentLyricIndex != -1) {
        _currentLyricIndex = -1;
        notifyListeners();
      }
      return;
    }

    int newIndex = -1;
    // Binary search for the current lyric line
    int low = 0;
    int high = _lyrics.length - 1;
    while (low <= high) {
      int mid = (low + (high - low) / 2).floor();
      if (_lyrics[mid].timestamp <= position) {
        if (mid == _lyrics.length - 1 ||
            _lyrics[mid + 1].timestamp > position) {
          newIndex = mid;
          break;
        }
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    if (newIndex != _currentLyricIndex) {
      _currentLyricIndex = newIndex;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
