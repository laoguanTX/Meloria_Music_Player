// ignore_for_file: avoid_print, unnecessary_brace_in_string_interps

import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:file_picker/file_picker.dart' as fp; // Aliased file_picker
import 'package:permission_handler/permission_handler.dart';
// import 'package:audio_metadata_reader/audio_metadata_reader.dart'; // Commented out or remove if not used elsewhere for reading
import 'package:flutter_taggy/flutter_taggy.dart'; // Added for flutter_taggy
import '../models/song.dart';
import '../models/playlist.dart'; // ADDED: Playlist model import
import '../models/lyric_line.dart'; // Added import for LyricLine
import '../services/database_service.dart';
import 'theme_provider.dart';
import 'dart:io';
// Added for Uint8List
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart'; // Required for kIsWeb
import 'dart:async'; // Added for Timer

enum PlayerState { stopped, playing, paused }

// enum RepeatMode { none, one, all } // Old Enum
enum RepeatMode { singlePlay, randomPlay, singleCycle, playlistLoop } // New Enum - 删除顺序播放模式

class MusicProvider with ChangeNotifier {
  final audio.AudioPlayer _audioPlayer = audio.AudioPlayer();
  final DatabaseService _databaseService = DatabaseService();
  ThemeProvider? _themeProvider; // 添加主题提供器引用

  List<Song> _songs = []; // 音乐库中的所有歌曲
  final List<Song> _playQueue = []; // 播放队列，独立于音乐库
  List<Playlist> _playlists = []; // ADDED: Playlists list
  List<MusicFolder> _folders = [];
  final List<Song> _history = []; // 添加播放历史列表
  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  // RepeatMode _repeatMode = RepeatMode.none; // Old default
  RepeatMode _repeatMode = RepeatMode.singlePlay; // New default - 改为单曲播放
  // bool _shuffleMode = false; // REMOVED
  String _sortType = 'date'; // 默认排序方式
  bool _sortAscending = false; // 默认降序
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _currentIndex = 0;
  double _volume = 1.0; // 添加音量控制变量
  double _volumeBeforeMute = 0.7; // 记录静音前的音量
  bool _isGridView = false; // 添加视图模式状态，默认为列表视图
  // bool _isExclusiveAudioMode = false; // REMOVED: 旧的音频独占模式状态
  bool _isDesktopLyricMode = false; // ADDED: 桌面歌词模式状态

  // 自动扫描相关字段
  Timer? _autoScanTimer;
  final Map<String, StreamSubscription> _fileWatchers = {};
  bool _isAutoScanning = false;
  String _currentScanStatus = '';
  int _scanProgress = 0;
  int _totalFilesToScan = 0;

  List<LyricLine> _lyrics = [];
  List<LyricLine> get lyrics => _lyrics;
  int _currentLyricIndex = -1;
  int get currentLyricIndex => _currentLyricIndex;

  // Getters
  List<Song> get songs => _songs; // 音乐库中的所有歌曲
  List<Song> get playQueue => _playQueue; // 播放队列
  List<Playlist> get playlists => _playlists; // ADDED: Playlists getter
  List<MusicFolder> get folders => _folders;
  List<Song> get history => _history; // 添加 history getter
  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  RepeatMode get repeatMode => _repeatMode;
  // bool get shuffleMode => _shuffleMode; // REMOVED
  bool get sortAscending => _sortAscending;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _playerState == PlayerState.playing;
  double get volume => _volume; // 添加音量getter
  bool get isGridView => _isGridView; // 添加视图模式getter
  // bool get isExclusiveAudioMode => _isExclusiveAudioMode; // REMOVED: 旧的音频独占模式 getter
  bool get isDesktopLyricMode => _isDesktopLyricMode; // ADDED: 桌面歌词模式 getter

  // 扫描状态 getters
  bool get isAutoScanning => _isAutoScanning;
  String get currentScanStatus => _currentScanStatus;
  int get scanProgress => _scanProgress;
  int get totalFilesToScan => _totalFilesToScan;

  // Method to allow seeking to a specific position
  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
    _currentPosition = position; // Immediately update current position
    if (_currentSong != null && _currentSong!.hasLyrics) {
      updateLyric(position); // Update lyrics based on new position
    }
    notifyListeners();
  }

  MusicProvider() {
    _initAudioPlayer();
    _loadInitialData(); // Consolidated loading method
    _initAutoScan(); // 初始化自动扫描
  }

  Future<void> _loadInitialData() async {
    await _loadSongs();
    await _loadHistory();
    await _loadPlaylists(); // ADDED: Load playlists
    await _loadFolders(); // 加载文件夹
    // Other initial loading if necessary
  }

  // ADDED: Method to add multiple songs to a playlist
  Future<void> addSongsToPlaylist(String playlistId, List<String> songIds) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      // Add song IDs that are not already in the playlist
      final Set<String> currentSongIds = Set.from(_playlists[playlistIndex].songIds);
      for (String songId in songIds) {
        if (!currentSongIds.contains(songId)) {
          _playlists[playlistIndex].songIds.add(songId);
        }
      }
      await _databaseService.updatePlaylist(_playlists[playlistIndex]);
      notifyListeners();
    } else {
      print("Playlist with ID $playlistId not found.");
    }
  }

  // CORRECTED: Method to remove a song from a playlist
  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final bool removed = _playlists[playlistIndex].songIds.remove(songId);
      if (removed) {
        await _databaseService.updatePlaylist(_playlists[playlistIndex]);
        notifyListeners();
      } else {
        print("Song ID $songId not found in playlist $playlistId's songIds list during removal attempt.");
      }
    } else {
      print("Playlist with ID $playlistId not found for song removal.");
    }
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

  // 根据艺术家获取歌曲列表
  List<Song> getSongsByArtist(String artist) {
    if (_songs.isEmpty) {
      return [];
    }
    return _songs.where((song) => song.artist == artist).toList();
  }

  // 根据专辑获取歌曲列表
  List<Song> getSongsByAlbum(String album) {
    if (_songs.isEmpty) {
      return [];
    }
    return _songs.where((song) => song.album == album).toList();
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

    // 位置变化监听，直接更新避免防抖延迟影响歌词滚动
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;

      // 立即更新歌词，确保歌词滚动及时响应
      if (_currentSong != null && _currentSong!.hasLyrics) {
        updateLyric(position);
      }

      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_currentSong != null) {
        _databaseService.incrementPlayCount(_currentSong!.id);
        _addSongToHistory(_currentSong!); // Add to history on completion
      }
      _onSongComplete();
    });

    // 优化播放器状态变化监听，减少不必要的UI更新
    PlayerState? lastPlayerState;
    _audioPlayer.onPlayerStateChanged.listen((audio.PlayerState state) {
      PlayerState newState;
      switch (state) {
        case audio.PlayerState.playing:
          newState = PlayerState.playing;
          break;
        case audio.PlayerState.paused:
          newState = PlayerState.paused;
          break;
        case audio.PlayerState.stopped:
          newState = PlayerState.stopped;
          break;
        case audio.PlayerState.completed:
          newState = PlayerState.stopped;
          break;
        default:
          return; // 忽略未知状态
      }

      // 只有当状态真正改变时才更新UI
      if (lastPlayerState != newState) {
        lastPlayerState = newState;
        _playerState = newState;
        notifyListeners();
      }
    });
  }

  Future<void> _loadSongs() async {
    _songs = await _databaseService.getAllSongs();
    // _playlists = await _databaseService.getAllPlaylists(); // REMOVED: No longer loading playlists
    _folders = await _databaseService.getAllFolders();
    // 应用默认排序：按添加时间降序（后添加的在前面）
    sortSongs(_sortType);
  }

  Future<void> _loadPlaylists() async {
    // MODIFIED: Ensure songIds are loaded correctly
    final playlistMaps = await _databaseService.getAllPlaylists(); // This now returns playlists with songIds
    _playlists = playlistMaps.map((map) {
      List<String> loadedSongIds = [];
      if (map['songIds'] != null && map['songIds'] is List) {
        // Convert all items in the list to String, in case they are of other types (e.g., int)
        loadedSongIds = (map['songIds'] as List).map((item) => item.toString()).toList();
      }
      // songIds will be an empty list if no songs are in the playlist
      return Playlist(
        id: map['id'] as String,
        name: map['name'] as String,
        songIds: loadedSongIds, // Crucial: Initialize Playlist with its song IDs
      );
    }).toList();
    notifyListeners();
  }

  Future<void> _loadHistory() async {
    final historySongs = await _databaseService.getHistorySongs();
    _history.clear();
    _history.addAll(historySongs);
    notifyListeners();
  }

  Future<void> _loadFolders() async {
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
    List<String> supportedFormats = ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma'];
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
        final titleAndArtist = _extractTitleAndArtist(filePath, null); // Pass null as metadata
        title = titleAndArtist['title']!;
        artist = titleAndArtist['artist']!;
        // Temporary fallback if _extractTitleAndArtist is not yet implemented
        // title = filePath.split('/').last.split('.').first;
        // artist = 'Unknown Artist';
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
      // Temporary fallback if _extractTitleAndArtist is not yet implemented
      // title = fileName.substring(0, fileName.lastIndexOf('.'));
      // artist = 'Unknown Artist';

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
    // 如果播放队列为空，将当前歌曲添加到播放队列
    if (_playQueue.isEmpty) {
      if (_repeatMode == RepeatMode.playlistLoop) {
        // 播放列表循环模式下，如果播放队列为空，不应该播放任何歌曲
        print('Warning: 播放列表循环模式下播放队列为空，无法播放歌曲');
        return;
      }
      _playQueue.add(song);
      _currentIndex = 0;
    } else {
      // 在播放队列中查找歌曲
      int foundIndex = _playQueue.indexWhere((s) => s.id == song.id);

      if (index != null && index >= 0 && index < _playQueue.length && _playQueue[index].id == song.id) {
        // 如果提供了有效的索引且指向正确的歌曲，使用它
        _currentIndex = index;
      } else if (foundIndex != -1) {
        // 如果在播放队列中找到歌曲，使用其索引
        _currentIndex = foundIndex;
      } else {
        // 歌曲不在播放队列中的处理
        if (_repeatMode == RepeatMode.playlistLoop) {
          // 播放列表循环模式下，将歌曲添加到播放队列并播放
          _playQueue.add(song);
          _currentIndex = _playQueue.length - 1;
        } else {
          // 其他模式下，将歌曲添加到队列末尾
          _playQueue.add(song);
          _currentIndex = _playQueue.length - 1;
        }
      }
    }

    // 更新当前歌曲
    _currentSong = song;

    // 确保索引有效
    if (_currentIndex < 0 || _currentIndex >= _playQueue.length) {
      await stop();
      _currentSong = null;
      notifyListeners();
      return;
    }

    // 立即通知UI更新歌曲信息，避免卡顿
    notifyListeners();

    // 使用Future.wait并行执行多个异步操作
    await Future.wait([
      // 播放音频
      _playAudio(song),
      // 异步更新主题（不阻塞播放）
      _updateThemeAsync(song),
      // 异步加载歌词（不阻塞播放）
      _loadLyricsAsync(song),
      // 异步更新播放历史和计数（不阻塞播放）
      _updatePlayHistoryAsync(song),
    ]);
  }

  // 新增：线程安全的音频播放方法
  Future<void> _playAudio(Song song) async {
    try {
      // 确保在主线程上执行音频操作
      await _audioPlayer.stop(); // 先停止当前播放

      if (kIsWeb) {
        await _audioPlayer.play(audio.UrlSource(song.filePath));
      } else {
        await _audioPlayer.play(audio.DeviceFileSource(song.filePath));
      }
      _playerState = PlayerState.playing;
    } catch (e) {
      print('Error playing audio: $e');
      _playerState = PlayerState.stopped;
    }
  }

  // 新增：异步更新主题方法
  Future<void> _updateThemeAsync(Song song) async {
    if (_themeProvider != null && song.albumArt != null) {
      await _themeProvider!.updateThemeFromAlbumArt(song.albumArt);
    } else if (_themeProvider != null) {
      _themeProvider!.resetToDefault(); // Reset to default if no album art
    }
  }

  // 新增：异步加载歌词方法
  Future<void> _loadLyricsAsync(Song song) async {
    if (song.hasLyrics) {
      await loadLyrics(song);
    } else {
      _lyrics = []; // Clear lyrics if the new song doesn't have any
      _currentLyricIndex = -1;
      notifyListeners();
    }
  }

  // 新增：异步更新播放历史方法
  Future<void> _updatePlayHistoryAsync(Song song) async {
    _addSongToHistory(song); // Add to history when a song starts playing
    await _databaseService.incrementPlayCount(song.id); // Increment play count
  }

  // 新增：只更新播放计数，不添加到历史记录的方法
  Future<void> _updatePlayCountOnlyAsync(Song song) async {
    await _databaseService.incrementPlayCount(song.id); // Increment play count only
  }

  void _addSongToHistory(Song song) {
    // Remove if already exists to move it to the top (most recent)
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song); // Add to the beginning of the list

    // Limit history size (e.g., to 100 songs in memory)
    if (_history.length > 100) {
      _history.removeLast();
    }
    _databaseService.insertHistorySong(song.id); // Persist to DB
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    sortSongs(_sortType); // 使用当前排序类型重新排序
  }

  // Method to remove a song from history (in-memory and DB)
  // This replaces the original simpler removeFromHistory
  Future<void> removeFromHistory(String songId) async {
    _history.removeWhere((s) => s.id == songId);
    await _databaseService.removeHistorySong(songId); // Remove from DB
    notifyListeners();
  }

  // Method to clear all history (in-memory and DB)
  Future<void> clearAllHistory() async {
    _history.clear();
    await _databaseService.clearHistory(); // Clear from DB
    notifyListeners();
  }

  void sortSongs(String sortBy) {
    _sortType = sortBy;
    int order = _sortAscending ? 1 : -1;
    _songs.sort((a, b) {
      int result;
      switch (sortBy) {
        case 'title':
          result = a.title.compareTo(b.title);
          break;
        case 'artist':
          result = a.artist.compareTo(b.artist);
          break;
        case 'album':
          result = a.album.compareTo(b.album);
          break;
        case 'duration':
          result = a.duration.compareTo(b.duration);
          break;
        case 'date':
          result = a.id.compareTo(b.id);
        default:
          result = a.id.compareTo(b.id);
          break;
      }
      return result * order;
    });
    notifyListeners();
  }

  // ADDED: Method to load and parse lyrics
  Future<void> loadLyrics(Song song) async {
    _lyrics = [];
    _currentLyricIndex = -1;
    String? lyricData;

    if (song.embeddedLyrics != null && song.embeddedLyrics!.isNotEmpty) {
      lyricData = song.embeddedLyrics;
      // print("Loading embedded lyrics for ${song.title}");
    } else {
      // Try to load from .lrc file
      try {
        String lrcFilePath = '${path.withoutExtension(song.filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          lyricData = await lrcFile.readAsString();
          // print("Loading lyrics from .lrc file for ${song.title}");
        } else {
          // print("No .lrc file found for ${song.title}");
        }
      } catch (e) {
        // print("Error loading .lrc file for ${song.title}: $e");
      }
    }

    if (lyricData != null) {
      _lyrics = _parseLrcLyrics(lyricData);
      if (_lyrics.isNotEmpty) {
        // print("Successfully parsed ${_lyrics.length} lyric lines for ${song.title}.");
        // 在调试控制台输出歌词信息
        // for (var lyricLine in _lyrics) {
        //   print("Timestamp: ${lyricLine.timestamp}, Text: ${lyricLine.text}, TranslatedText: ${lyricLine.translatedText}");
        // }
      } else {
        // print("Parsed lyrics but the list is empty for ${song.title}.");
      }
    } else {
      // print("No lyric data found for ${song.title}.");
    }
    notifyListeners();
  }

  List<LyricLine> _parseLrcLyrics(String lrcData) {
    final List<LyricLine> tempLines = [];
    // Regex to find all time tags in a line, for lyrics with multiple timestamps
    // Handles [mm:ss.xx] and [mm:ss.xxx]
    final RegExp timeTagRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (String lineStr in lrcData.split('\n')) {
      // BUG: Should be split('\n')
      String currentLine = lineStr.trim();
      if (currentLine.isEmpty) continue;

      Iterable<RegExpMatch> timeMatches = timeTagRegex.allMatches(currentLine);

      // Check if iterator has elements without advancing it.
      // If no time tags, it might be metadata or an invalid line, skip.
      if (!timeMatches.iterator.moveNext()) {
        continue;
      }
      // Reset iterator for actual use below if needed, or just use the result of allMatches directly.
      timeMatches = timeTagRegex.allMatches(currentLine); // Re-evaluate to get a fresh iterable

      String fullLyricText = "";
      int lastTimestampEndIndex = currentLine.lastIndexOf(']');
      if (lastTimestampEndIndex != -1 && lastTimestampEndIndex + 1 < currentLine.length) {
        fullLyricText = currentLine.substring(lastTimestampEndIndex + 1).trim();
      }
      String lyricText = fullLyricText;
      String? providedTranslatedText;

      if (fullLyricText.contains('|')) {
        var parts = fullLyricText.split('|');
        lyricText = parts[0].trim();
        if (parts.length > 1) {
          providedTranslatedText = parts[1].trim();
        }
      }

      for (RegExpMatch match in timeMatches) {
        try {
          int minutes = int.parse(match.group(1)!);
          int seconds = int.parse(match.group(2)!);
          String msPart = match.group(3)!;
          int milliseconds = int.parse(msPart) * (msPart.length == 2 ? 10 : 1);

          Duration timestamp = Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
          tempLines.add(LyricLine(timestamp, lyricText, translatedText: providedTranslatedText));
        } catch (e) {
          // print("Error parsing LRC timestamp or creating temp LyricLine: '$currentLine' - $e");
        }
      }
    }

    if (tempLines.isEmpty) return [];

    // 使用稳定排序确保相同时间戳的歌词行保持原始顺序
    // 先给每个歌词行添加原始索引，然后进行稳定排序
    List<MapEntry<int, LyricLine>> indexedLines = [];
    for (int i = 0; i < tempLines.length; i++) {
      indexedLines.add(MapEntry(i, tempLines[i]));
    }

    // 稳定排序：首先按时间戳排序，如果时间戳相同则按原始索引排序
    indexedLines.sort((a, b) {
      int timeComparison = a.value.timestamp.compareTo(b.value.timestamp);
      if (timeComparison != 0) {
        return timeComparison;
      }
      // 如果时间戳相同，按原始索引排序以保持稳定性
      return a.key.compareTo(b.key);
    });

    // 提取排序后的歌词行并创建新的列表
    final List<LyricLine> sortedTempLines = indexedLines.map((entry) => entry.value).toList();

    final List<LyricLine> finalLines = [];
    if (sortedTempLines.isNotEmpty) {
      // 使用Map来收集同一时间戳的所有歌词行
      Map<Duration, List<String>> timestampGroups = {};

      for (LyricLine lyric in sortedTempLines) {
        if (!timestampGroups.containsKey(lyric.timestamp)) {
          timestampGroups[lyric.timestamp] = [];
        }
        timestampGroups[lyric.timestamp]!.add(lyric.text);
      }

      // 按时间戳顺序处理歌词组
      List<Duration> sortedTimestamps = timestampGroups.keys.toList()..sort();

      for (Duration timestamp in sortedTimestamps) {
        List<String> texts = timestampGroups[timestamp]!;

        if (texts.length == 1) {
          // 单句歌词
          finalLines.add(LyricLine(timestamp, texts[0]));
        } else {
          // 多句歌词，合并为一个LyricLine，使用换行符分隔
          String combinedText = texts.join('\n');
          finalLines.add(LyricLine(timestamp, combinedText));
        }
      }
    }

    return finalLines;
  }

  // ADDED: Method to update current lyric based on playback position
  void updateLyric(Duration currentPosition) {
    if (_lyrics.isEmpty) {
      if (_currentLyricIndex != -1) {
        _currentLyricIndex = -1;
        notifyListeners();
      }
      return;
    }

    // 优化：使用提前0.5秒的二分查找快速定位歌词行（用于滚动显示）
    int newLyricIndex = _findLyricIndexForScrolling(currentPosition);

    // 只有当歌词索引真正改变时才更新UI
    if (newLyricIndex != _currentLyricIndex) {
      _currentLyricIndex = newLyricIndex;
      notifyListeners();
    }
  }

  // 新增：用于歌词滚动的索引查找，提前0.5秒显示歌词
  int _findLyricIndexForScrolling(Duration currentPosition) {
    if (_lyrics.isEmpty) return -1;

    // 提前0.5秒显示歌词
    final adjustedPosition = currentPosition + const Duration(milliseconds: 500);

    int left = 0;
    int right = _lyrics.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      if (_lyrics[mid].timestamp <= adjustedPosition) {
        result = mid;
        left = mid + 1;
      } else {
        right = mid - 1;
      }
    }

    return result;
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

  // MODIFIED: Renamed from toggleExclusiveAudioMode and updated comment
  // 新增：切换桌面歌词模式
  Future<void> toggleDesktopLyricMode() async {
    _isDesktopLyricMode = !_isDesktopLyricMode;
    // 此处未来可以添加实际控制桌面歌词显示的代码
    // 目前仅更新状态并通知
    notifyListeners();
  }

  Future<void> nextSong() async {
    if (_playQueue.isEmpty) return;

    try {
      // 在非播放列表循环模式下，确保播放队列包含所有歌曲
      _ensureFullLibraryInQueue();

      // 先停止当前播放，确保线程安全
      await _audioPlayer.stop();
      _playerState = PlayerState.stopped;

      // 计算新的索引
      int newIndex;
      if (_repeatMode == RepeatMode.randomPlay) {
        if (_playQueue.length > 1) {
          do {
            newIndex = (DateTime.now().millisecondsSinceEpoch % _playQueue.length);
          } while (newIndex == _currentIndex && _playQueue.length > 1);
        } else {
          newIndex = 0;
        }
      } else if (_repeatMode == RepeatMode.playlistLoop) {
        // 播放列表循环模式：循环播放播放队列中的歌曲
        newIndex = (_currentIndex + 1) % _playQueue.length;
      } else {
        newIndex = (_currentIndex + 1) % _playQueue.length;
      }

      // 验证索引有效性
      if (newIndex >= 0 && newIndex < _playQueue.length) {
        _currentIndex = newIndex;
        await playSong(_playQueue[_currentIndex], index: _currentIndex);
      } else {
        // 索引无效时的处理
        if (_playQueue.isNotEmpty) {
          _currentIndex = 0;
          await playSong(_playQueue[_currentIndex], index: _currentIndex);
        } else {
          await stop();
        }
      }
    } catch (e) {
      print('Error in nextSong: $e');
      _playerState = PlayerState.stopped;
      notifyListeners();
    }
  }

  Future<void> previousSong() async {
    if (_playQueue.isEmpty) return;

    try {
      // 在非播放列表循环模式下，确保播放队列包含所有歌曲
      _ensureFullLibraryInQueue();

      // 先停止当前播放，确保线程安全
      await _audioPlayer.stop();
      _playerState = PlayerState.stopped;

      // 计算新的索引
      int newIndex;
      if (_repeatMode == RepeatMode.randomPlay) {
        // 随机播放模式下，从历史记录中获取上一首歌
        if (_history.length > 1) {
          // 找到当前歌曲在历史记录中的位置
          int currentHistoryIndex = _history.indexWhere((s) => s.id == _currentSong?.id);

          if (currentHistoryIndex != -1 && currentHistoryIndex < _history.length - 1) {
            // 获取历史记录中的上一首歌（索引+1，因为历史记录是按最新到最旧排序的）
            Song previousSong = _history[currentHistoryIndex + 1];

            // 在播放队列中查找这首歌
            int queueIndex = _playQueue.indexWhere((s) => s.id == previousSong.id);

            if (queueIndex != -1) {
              // 如果在播放队列中找到了，直接播放
              _currentIndex = queueIndex;
              await _playSongWithoutHistory(_playQueue[_currentIndex], index: _currentIndex);
              return;
            } else {
              // 如果不在播放队列中，添加到队列并播放
              _playQueue.add(previousSong);
              _currentIndex = _playQueue.length - 1;
              await _playSongWithoutHistory(previousSong, index: _currentIndex);
              return;
            }
          }
        }

        // 如果没有历史记录或者已经是历史记录中最旧的歌曲，使用随机播放逻辑
        if (_playQueue.length > 1) {
          do {
            newIndex = (DateTime.now().millisecondsSinceEpoch % _playQueue.length);
          } while (newIndex == _currentIndex && _playQueue.length > 1);
        } else {
          newIndex = 0;
        }
      } else if (_repeatMode == RepeatMode.playlistLoop) {
        // 播放列表循环模式：循环播放播放队列中的歌曲
        newIndex = (_currentIndex - 1 + _playQueue.length) % _playQueue.length;
      } else {
        newIndex = (_currentIndex - 1 + _playQueue.length) % _playQueue.length;
      }

      // 验证索引有效性
      if (newIndex >= 0 && newIndex < _playQueue.length) {
        _currentIndex = newIndex;
        await playSong(_playQueue[_currentIndex], index: _currentIndex);
      } else {
        // 索引无效时的处理
        if (_playQueue.isNotEmpty) {
          _currentIndex = 0;
          await playSong(_playQueue[_currentIndex], index: _currentIndex);
        } else {
          await stop();
        }
      }
    } catch (e) {
      print('Error in previousSong: $e');
      _playerState = PlayerState.stopped;
      notifyListeners();
    }
  }

  // 新增：播放歌曲但不更新历史记录的公共方法（用于从历史记录播放）
  Future<void> playSongWithoutHistory(Song song, {int? index}) async {
    await _playSongWithoutHistory(song, index: index);
  }

  // 新增：播放歌曲但不更新历史记录的方法（用于随机播放模式下的上一首）
  Future<void> _playSongWithoutHistory(Song song, {int? index}) async {
    // 如果播放队列为空，将当前歌曲添加到播放队列
    if (_playQueue.isEmpty) {
      _playQueue.add(song);
      _currentIndex = 0;
    } else {
      // 在播放队列中查找歌曲
      int foundIndex = _playQueue.indexWhere((s) => s.id == song.id);

      if (index != null && index >= 0 && index < _playQueue.length && _playQueue[index].id == song.id) {
        // 如果提供了有效的索引且指向正确的歌曲，使用它
        _currentIndex = index;
      } else if (foundIndex != -1) {
        // 如果在播放队列中找到歌曲，使用其索引
        _currentIndex = foundIndex;
      } else {
        // 歌曲不在播放队列中，将其添加到队列末尾
        _playQueue.add(song);
        _currentIndex = _playQueue.length - 1;
      }
    }

    // 更新当前歌曲
    _currentSong = song;

    // 确保索引有效
    if (_currentIndex < 0 || _currentIndex >= _playQueue.length) {
      await stop();
      _currentSong = null;
      notifyListeners();
      return;
    }

    // 立即通知UI更新歌曲信息，避免卡顿
    notifyListeners();

    // 使用Future.wait并行执行异步操作，但不包括历史记录更新
    await Future.wait([
      // 播放音频
      _playAudio(song),
      // 异步更新主题（不阻塞播放）
      _updateThemeAsync(song),
      // 异步加载歌词（不阻塞播放）
      _loadLyricsAsync(song),
      // 只更新播放计数，不添加到历史记录
      _updatePlayCountOnlyAsync(song),
    ]);
  }

  void _onSongComplete() {
    if (_currentSong == null || _playQueue.isEmpty) {
      stop();
      return;
    }

    switch (_repeatMode) {
      case RepeatMode.singlePlay:
        stop();
        break;
      case RepeatMode.randomPlay:
        if (_playQueue.isNotEmpty) {
          // 异步播放下一首歌曲，避免阻塞
          nextSong();
        } else {
          stop();
        }
        break;
      case RepeatMode.singleCycle:
        // 异步重播当前歌曲，避免阻塞
        playSong(_currentSong!, index: _currentIndex);
        break;
      case RepeatMode.playlistLoop:
        // 播放列表循环：播放下一首，如果到最后一首则循环到第一首
        if (_currentIndex < _playQueue.length - 1) {
          _currentIndex++;
        } else {
          _currentIndex = 0; // 循环到第一首
        }
        playSong(_playQueue[_currentIndex], index: _currentIndex);
        break;
    }
  }

  void toggleRepeatMode() {
    switch (_repeatMode) {
      case RepeatMode.singlePlay:
        _repeatMode = RepeatMode.randomPlay;
        break;
      case RepeatMode.randomPlay:
        _repeatMode = RepeatMode.playlistLoop;
        break;
      case RepeatMode.playlistLoop:
        _repeatMode = RepeatMode.singleCycle;
        break;
      case RepeatMode.singleCycle:
        _repeatMode = RepeatMode.singlePlay;
        break;
    }
    notifyListeners();
  }

  // void toggleShuffle() { // REMOVED
  //   _shuffleMode = !_shuffleMode;
  //   notifyListeners();
  // }

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
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
          _currentIndex = -1; // Reset current index
        } else if (_currentSong != null && songIndex < _currentIndex) {
          // 如果删除的歌曲在当前播放歌曲之前，调整索引
          _currentIndex--;
        }

        // 如果删除后列表为空，重置播放状态
        if (_songs.isEmpty) {
          await stop();
          _currentSong = null;
          _currentIndex = -1; // Reset current index
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
      await _databaseService.deleteSongs(songIds); // Database service handles cascading deletes if any were set up

      bool currentSongWasDeleted = false;
      if (_currentSong != null && songIds.contains(_currentSong!.id)) {
        currentSongWasDeleted = true;
      }

      _songs.removeWhere((song) => songIds.contains(song.id));

      if (currentSongWasDeleted) {
        await stop();
        _currentSong = null;
        _currentIndex = -1;
        if (_songs.isNotEmpty) {
          // Optionally, play the next available song or just stop
        }
      } else {
        // Re-evaluate currentIndex if songs before it were deleted
        if (_currentSong != null) {
          final newCurrentIndex = _songs.indexWhere((s) => s.id == _currentSong!.id);
          if (newCurrentIndex != -1) {
            _currentIndex = newCurrentIndex;
          } else {
            // This case should ideally not happen if current song wasn't in songIds
            // but as a fallback, reset.
            await stop();
            _currentSong = null;
            _currentIndex = -1;
          }
        }
      }

      if (_songs.isEmpty) {
        await stop();
        _currentSong = null;
        _currentIndex = -1;
      }

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  // 获取音乐库统计信息
  Future<Map<String, int>> getLibraryStats() async {
    final songCount = await _databaseService.getSongCount();
    // final playlistCount = _playlists.length; // REMOVED: Playlist count

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
      // 'playlists': playlistCount, // REMOVED: Playlist count
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
    await _loadPlaylists(); // ADDED: Reload playlists
  }

  // 刷新音乐库
  Future<void> refreshLibrary() async {
    await _loadSongs();
  }

  // 歌曲排序方法
  // void sortSongs(String sortBy) {
  //   switch (sortBy) {
  //     case 'title':
  //       _songs.sort((a, b) => a.title.compareTo(b.title));
  //       break;
  //     case 'artist':
  //       _songs.sort((a, b) => a.artist.compareTo(b.artist));
  //       break;
  //     case 'album':
  //       _songs.sort((a, b) => a.album.compareTo(b.album));
  //       break;
  //     case 'duration':
  //       _songs.sort((a, b) => a.duration.compareTo(b.duration));
  //       break;
  //     case 'date':
  //       _songs.sort((a, b) => b.id.compareTo(a.id));
  //       break;
  //     default:
  //       _songs.sort((a, b) => a.title.compareTo(b.title));
  //   }
  //   notifyListeners();
  // }

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

  // 从文件名提取标题和艺术家
  Map<String, String> _extractTitleAndArtist(String filePath, dynamic metadata) {
    // metadata 参数当前未使用，但保留以备将来扩展
    String fileName = path.basenameWithoutExtension(filePath);
    return _parseMetadataFromFilename(fileName);
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
          String part2 = parts[1].trim(); // 只有当数字后面跟着点号和空格时（如 "01. "），才认为是曲目编号并去掉
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
      RegExp bracketPattern = RegExp(r'^(.+?)\s*[\[\(]([^\[\]\(\)]+)[\]\)](.*)$');
      Match? match = bracketPattern.firstMatch(workingFilename);

      if (match != null) {
        String titlePart = match.group(1)?.trim() ?? '';
        String bracketContent = match.group(2)?.trim() ?? '';
        String remainingPart = match.group(3)?.trim() ?? '';

        // 如果括号内容看起来像艺术家名，提取它
        if (bracketContent.isNotEmpty && bracketContent.length > 1) {
          title = titlePart + (remainingPart.isNotEmpty ? ' $remainingPart' : '');
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
      String? selectedDirectory = await fp.FilePicker.platform.getDirectoryPath(); // Use aliased FilePicker
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

  Future<void> scanFolderForMusic(MusicFolder folder, {bool isBackgroundScan = false}) async {
    try {
      final directory = Directory(folder.path);
      if (!directory.existsSync()) {
        throw Exception('文件夹不存在: ${folder.path}');
      }

      final musicFiles = <FileSystemEntity>[];
      final supportedExtensions = ['.mp3', '.m4a', '.aac', '.flac', '.wav', '.ogg'];

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
      if (isBackgroundScan) {
        _totalFilesToScan = musicFiles.length;
        _scanProgress = 0;
        notifyListeners();
      }

      for (int i = 0; i < musicFiles.length; i++) {
        final file = musicFiles[i];
        try {
          await _processMusicFile(File(file.path));

          if (isBackgroundScan) {
            _scanProgress = i + 1;
            notifyListeners();
          }
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
    final String fileId = filePath; // 使用文件路径作为ID，确保唯一性

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
        final titleAndArtist = _extractTitleAndArtist(filePath, null); // Pass null as metadata
        title = titleAndArtist['title']!;
        artist = titleAndArtist['artist']!;
        // Temporary fallback if _extractTitleAndArtist is not yet implemented
        // title = filePath.split('/').last.split('.').first;
        // artist = 'Unknown Artist';
      }
      final String fileName = path.basename(filePath);
      if (title.isEmpty) {
        title = fileName.substring(0, fileName.lastIndexOf('.') > -1 ? fileName.lastIndexOf('.') : fileName.length);
      }
      if (artist.isEmpty) {
        artist = 'Unknown Artist';
      }

      // 根据歌曲名称、专辑、艺术家检查歌曲是否已存在
      if (await _databaseService.songExistsByMetadata(title, artist, album)) {
        return; // 跳过已存在的歌曲
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
        title = fileName.substring(0, fileName.lastIndexOf('.') > -1 ? fileName.lastIndexOf('.') : fileName.length);
      }
      if (artist.isEmpty) {
        artist = 'Unknown Artist';
      }

      // 根据歌曲名称、专辑、艺术家检查歌曲是否已存在
      if (await _databaseService.songExistsByMetadata(title, artist, album)) {
        return; // 跳过已存在的歌曲
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

  // 创建新歌单
  Future<void> createPlaylist(String name) async {
    final newPlaylist = Playlist(name: name);
    await _databaseService.insertPlaylist(newPlaylist);
    await _loadPlaylists(); // 重新加载歌单列表
  }

  // 删除歌单
  Future<void> deletePlaylist(String playlistId) async {
    await _databaseService.deletePlaylist(playlistId);
    await _loadPlaylists(); // 重新加载歌单列表
  }

  // 重命名歌单
  Future<void> renamePlaylist(String playlistId, String newName) async {
    await _databaseService.renamePlaylist(playlistId, newName);
    await _loadPlaylists(); // 重新加载歌单列表
  }

  // 向歌单添加歌曲
  Future<void> addSongToPlaylist(String songId, String playlistId) async {
    try {
      await _databaseService.addSongToPlaylist(songId, playlistId);
      // Optionally, load the playlist again or update in memory
      await _loadPlaylists();
    } catch (e) {
      throw Exception('添加歌曲到歌单失败: $e');
    }
  }

  // 获取歌单中的歌曲
  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    return await _databaseService.getSongsForPlaylist(playlistId);
  }

  // Method to find duplicate songs based on title, artist, and album
  Map<String, List<Song>> findDuplicateSongs() {
    Map<String, List<Song>> duplicateGroups = {};

    for (Song song in _songs) {
      // Create a key using title, artist, and album (case insensitive)
      String key = '${song.title.toLowerCase()}_${song.artist.toLowerCase()}_${song.album.toLowerCase()}';

      if (duplicateGroups.containsKey(key)) {
        duplicateGroups[key]!.add(song);
      } else {
        duplicateGroups[key] = [song];
      }
    }

    // Filter out groups that have only one song (not duplicates)
    duplicateGroups.removeWhere((key, songs) => songs.length <= 1);

    return duplicateGroups;
  }

  // Method to delete selected duplicate songs
  Future<bool> deleteDuplicateSongs(List<String> songIdsToDelete) async {
    try {
      // Use existing deleteSongs method
      return await deleteSongs(songIdsToDelete);
    } catch (e) {
      print('Error deleting duplicate songs: $e');
      return false;
    }
  }

  // 确保播放队列中包含所有歌曲（仅在非播放列表循环模式下）
  void _ensureFullLibraryInQueue() {
    if (_repeatMode == RepeatMode.playlistLoop) {
      // 播放列表循环模式下，不修改播放队列
      return;
    }

    // 检查播放队列是否包含了音乐库中的所有歌曲
    if (_playQueue.length != _songs.length) {
      // 保存当前播放的歌曲和索引
      Song? currentPlayingSong = _currentSong;

      // 清空播放队列并添加所有歌曲
      _playQueue.clear();
      _playQueue.addAll(_songs);

      // 如果有当前播放的歌曲，找到它在新队列中的位置
      if (currentPlayingSong != null) {
        int newIndex = _playQueue.indexWhere((song) => song.id == currentPlayingSong.id);
        if (newIndex != -1) {
          _currentIndex = newIndex;
        } else {
          _currentIndex = 0;
        }
      } else {
        _currentIndex = 0;
      }
    }
  }

  // 播放队列管理方法

  // 添加歌曲到播放队列
  void addToPlayQueue(Song song) {
    if (!_playQueue.any((s) => s.id == song.id)) {
      _playQueue.add(song);
      notifyListeners();
    }
  }

  // 批量添加歌曲到播放队列
  void addMultipleToPlayQueue(List<Song> songs) {
    for (Song song in songs) {
      if (!_playQueue.any((s) => s.id == song.id)) {
        _playQueue.add(song);
      }
    }
    notifyListeners();
  }

  // 从播放队列移除歌曲
  void removeFromPlayQueue(int index) {
    if (index >= 0 && index < _playQueue.length) {
      // 如果移除的是当前播放的歌曲
      if (index == _currentIndex) {
        if (_playQueue.length > 1) {
          // 如果队列中还有其他歌曲，播放下一首
          if (_currentIndex < _playQueue.length - 1) {
            // 不是最后一首，播放下一首
            _playQueue.removeAt(index);
            // _currentIndex 保持不变，因为下一首歌曲会移动到当前位置
            if (_currentIndex < _playQueue.length) {
              playSong(_playQueue[_currentIndex], index: _currentIndex);
            } else {
              // 队列已空，停止播放
              stop();
              _currentSong = null;
              _currentIndex = 0;
            }
          } else {
            // 是最后一首，播放前一首
            _playQueue.removeAt(index);
            if (_playQueue.isNotEmpty) {
              _currentIndex = _playQueue.length - 1;
              playSong(_playQueue[_currentIndex], index: _currentIndex);
            } else {
              // 队列已空，停止播放
              stop();
              _currentSong = null;
              _currentIndex = 0;
            }
          }
        } else {
          // 队列中只有这一首歌，停止播放
          _playQueue.removeAt(index);
          stop();
          _currentSong = null;
          _currentIndex = 0;
        }
      } else {
        // 移除的不是当前播放的歌曲
        _playQueue.removeAt(index);
        // 调整当前索引
        if (index < _currentIndex) {
          _currentIndex--;
        }

        // 检查删除后队列是否为空
        if (_playQueue.isEmpty) {
          stop();
          _currentSong = null;
          _currentIndex = 0;
        }
      }
      notifyListeners();
    }
  }

  // 批量从播放队列移除歌曲
  void removeMultipleFromPlayQueue(List<int> indices) {
    if (indices.isEmpty) return;

    // 按降序排序索引，确保删除时不会影响后续索引
    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

    bool currentSongWillBeRemoved = false;
    bool allSongsWillBeRemoved = false;

    // 检查是否要删除当前播放的歌曲
    if (_currentIndex >= 0 && indices.contains(_currentIndex)) {
      currentSongWillBeRemoved = true;
    }

    // 检查是否要删除所有歌曲
    if (indices.length == _playQueue.length) {
      allSongsWillBeRemoved = true;
    }

    // 逐个删除歌曲（按降序索引）
    for (final index in sortedIndices) {
      if (index >= 0 && index < _playQueue.length) {
        _playQueue.removeAt(index);

        // 调整当前索引
        if (index < _currentIndex) {
          _currentIndex--;
        } else if (index == _currentIndex) {
          // 当前歌曲被删除，先不处理播放逻辑
          _currentIndex = -1;
        }
      }
    }

    // 删除完成后，统一处理播放逻辑
    if (allSongsWillBeRemoved || _playQueue.isEmpty) {
      // 如果删除了所有歌曲或队列为空，停止播放
      stop();
      _currentSong = null;
      _currentIndex = 0;
    } else if (currentSongWillBeRemoved) {
      // 如果删除了当前播放的歌曲但队列不为空，播放下一首
      if (_currentIndex == -1 || _currentIndex >= _playQueue.length) {
        // 调整索引到有效范围
        _currentIndex = 0;
      }
      if (_currentIndex < _playQueue.length) {
        playSong(_playQueue[_currentIndex], index: _currentIndex);
      }
    }

    notifyListeners();
  }

  // 清空播放队列
  void clearPlayQueue() {
    _playQueue.clear();
    stop();
    _currentSong = null;
    _currentIndex = 0;
    notifyListeners();
  }

  // 播放全部歌曲：清空播放队列并将所有歌曲加入队列
  void playAllSongs() {
    if (_songs.isEmpty) return;

    // 清空当前播放队列
    _playQueue.clear();

    // 将所有歌曲添加到播放队列（使用当前顺序）
    _playQueue.addAll(_songs);

    // 设置循环模式为播放列表循环
    _repeatMode = RepeatMode.playlistLoop;

    // 开始播放第一首歌曲
    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  void playPlaylist(Playlist playlist) {
    if (playlist.songIds.isEmpty) return;

    // 获取歌单中的所有歌曲
    final playlistSongs = _songs.where((song) => playlist.songIds.contains(song.id)).toList();

    // 按照歌单中的歌曲顺序排序
    playlistSongs.sort((a, b) => playlist.songIds.indexOf(a.id).compareTo(playlist.songIds.indexOf(b.id)));

    if (playlistSongs.isEmpty) return;

    // 清空当前播放队列
    _playQueue.clear();

    // 将歌单中的歌曲添加到播放队列
    _playQueue.addAll(playlistSongs);

    // 设置循环模式为播放列表循环
    _repeatMode = RepeatMode.playlistLoop;

    // 开始播放第一首歌曲
    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  // 播放艺术家的所有歌曲：清空播放队列并将艺术家的所有歌曲加入队列
  void playAllByArtist(String artist) {
    if (_songs.isEmpty || artist.isEmpty) return;

    // 获取该艺术家的所有歌曲
    final artistSongs = _songs.where((song) => song.artist == artist).toList();

    if (artistSongs.isEmpty) return;

    // 清空当前播放队列
    _playQueue.clear();

    // 将艺术家的歌曲添加到播放队列
    _playQueue.addAll(artistSongs);

    // 设置循环模式为播放列表循环
    _repeatMode = RepeatMode.playlistLoop;

    // 开始播放第一首歌曲
    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  // 播放专辑的所有歌曲：清空播放队列并将专辑的所有歌曲加入队列
  void playAllByAlbum(String album, String artist) {
    if (_songs.isEmpty || album.isEmpty) return;

    // 获取该专辑的所有歌曲
    final albumSongs = _songs.where((song) => song.album == album && song.artist == artist).toList();

    // 按照歌曲标题排序（可以考虑按文件路径排序来保持专辑顺序）
    albumSongs.sort((a, b) => a.title.compareTo(b.title));

    if (albumSongs.isEmpty) return;

    // 清空当前播放队列
    _playQueue.clear();

    // 将专辑的歌曲添加到播放队列
    _playQueue.addAll(albumSongs);

    // 设置循环模式为播放列表循环
    _repeatMode = RepeatMode.playlistLoop;

    // 开始播放第一首歌曲
    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  // 移动播放队列中的歌曲位置
  void reorderPlayQueue(int oldIndex, int newIndex) {
    if (oldIndex < _playQueue.length && newIndex < _playQueue.length) {
      final Song song = _playQueue.removeAt(oldIndex);
      _playQueue.insert(newIndex, song);

      // 调整当前播放索引
      if (oldIndex == _currentIndex) {
        _currentIndex = newIndex;
      } else if (oldIndex < _currentIndex && newIndex >= _currentIndex) {
        _currentIndex--;
      } else if (oldIndex > _currentIndex && newIndex <= _currentIndex) {
        _currentIndex++;
      }
      notifyListeners();
    }
  }

  // 播放队列中的指定歌曲
  Future<void> playFromQueue(int index) async {
    if (index >= 0 && index < _playQueue.length) {
      _currentIndex = index;
      await playSong(_playQueue[index], index: index);
    }
  }

  // 初始化自动扫描
  void _initAutoScan() {
    _startAutoScanTimer();
  }

  // 启动自动扫描定时器
  void _startAutoScanTimer() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performScheduledScan();
    });
  }

  // 执行定时扫描
  Future<void> _performScheduledScan() async {
    if (_isAutoScanning) return; // 如果已经在扫描，跳过

    final now = DateTime.now();
    final autoScanFolders = _folders
        .where((folder) =>
            folder.isAutoScan && (folder.lastScanTime == null || now.difference(folder.lastScanTime!).inMinutes >= folder.scanIntervalMinutes))
        .toList();

    if (autoScanFolders.isNotEmpty) {
      await _scanFoldersInBackground(autoScanFolders);
    }
  }

  // 后台扫描文件夹
  Future<void> _scanFoldersInBackground(List<MusicFolder> foldersToScan) async {
    if (_isAutoScanning) return;

    _isAutoScanning = true;
    _scanProgress = 0;
    _totalFilesToScan = 0;
    notifyListeners();

    try {
      for (final folder in foldersToScan) {
        _currentScanStatus = '正在扫描: ${folder.name}';
        notifyListeners();

        await scanFolderForMusic(folder, isBackgroundScan: true);

        // 更新最后扫描时间
        await _updateFolderLastScanTime(folder.id);
      }

      _currentScanStatus = '扫描完成';
    } catch (e) {
      _currentScanStatus = '扫描失败: $e';
    } finally {
      _isAutoScanning = false;
      _scanProgress = 0;
      _totalFilesToScan = 0;
      notifyListeners();

      // 3秒后清除状态消息
      Timer(const Duration(seconds: 3), () {
        _currentScanStatus = '';
        notifyListeners();
      });
    }
  }

  // 更新文件夹最后扫描时间
  Future<void> _updateFolderLastScanTime(String folderId) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final updatedFolder = folder.copyWith(lastScanTime: DateTime.now());
      await _databaseService.updateFolder(updatedFolder);

      // 更新本地缓存
      final index = _folders.indexWhere((f) => f.id == folderId);
      if (index != -1) {
        _folders[index] = updatedFolder;
      }
    } catch (e) {
      print('更新文件夹扫描时间失败: $e');
    }
  }

  // 停止自动扫描
  void stopAutoScan() {
    _autoScanTimer?.cancel();
    _isAutoScanning = false;
    notifyListeners();
  }

  // 设置文件夹扫描间隔
  Future<void> setFolderScanInterval(String folderId, int intervalMinutes) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final updatedFolder = folder.copyWith(scanIntervalMinutes: intervalMinutes);

      await _databaseService.updateFolder(updatedFolder);
      _folders = await _databaseService.getAllFolders();
      notifyListeners();
    } catch (e) {
      throw Exception('设置扫描间隔失败: $e');
    }
  }

  // 手动触发智能扫描（只扫描有变化的文件夹）
  Future<void> smartScan() async {
    if (_isAutoScanning) return;

    final autoScanFolders = _folders.where((f) => f.isAutoScan).toList();
    if (autoScanFolders.isNotEmpty) {
      await _scanFoldersInBackground(autoScanFolders);
    }
  }

  @override
  void dispose() {
    _autoScanTimer?.cancel();
    for (final subscription in _fileWatchers.values) {
      subscription.cancel();
    }
    _fileWatchers.clear();
    _audioPlayer.dispose();
    super.dispose();
  }
}
