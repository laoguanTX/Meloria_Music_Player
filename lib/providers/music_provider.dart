import 'package:file_picker/file_picker.dart' as fp;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_taggy/flutter_taggy.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import '../models/lyric_line.dart';
import '../services/database_service.dart';
import '../services/bass_ffi_service.dart';
import '../utils/file_metadata_utils.dart';
import 'theme_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'dart:async';

enum PlayerState { stopped, playing, paused }

enum RepeatMode { singlePlay, randomPlay, singleCycle, playlistLoop }

class MusicProvider with ChangeNotifier {
  final BassFfiService _bassPlayer = BassFfiService.instance;
  final DatabaseService _databaseService = DatabaseService();
  ThemeProvider? _themeProvider;

  List<Song> _songs = [];
  final List<Song> _playQueue = [];
  List<Playlist> _playlists = [];
  List<MusicFolder> _folders = [];
  final List<Song> _history = [];
  Song? _currentSong;
  PlayerState _playerState = PlayerState.stopped;
  RepeatMode _repeatMode = RepeatMode.singlePlay;
  String _sortType = 'modifiedDate';
  bool _sortAscending = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  int _currentIndex = 0;
  double _volume = 0.5;
  double _volumeBeforeMute = 0.5;
  bool _isGridView = false;
  bool _isDesktopLyricMode = false;

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

  List<Song> get songs => _songs;
  List<Song> get playQueue => _playQueue;
  List<Playlist> get playlists => _playlists;
  List<MusicFolder> get folders => _folders;
  List<Song> get history => _history;
  Song? get currentSong => _currentSong;
  PlayerState get playerState => _playerState;
  RepeatMode get repeatMode => _repeatMode;
  bool get sortAscending => _sortAscending;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  int get currentIndex => _currentIndex;
  bool get isPlaying => _playerState == PlayerState.playing;
  double get volume => _volume;
  bool get isGridView => _isGridView;
  bool get isDesktopLyricMode => _isDesktopLyricMode;

  bool get isAutoScanning => _isAutoScanning;
  String get currentScanStatus => _currentScanStatus;
  int get scanProgress => _scanProgress;
  int get totalFilesToScan => _totalFilesToScan;

  // ===== 音频信息与电平对外暴露 =====
  int get sampleRate => _bassPlayer.sampleRate;
  int get channels => _bassPlayer.channels;
  int get bitrateKbps => _bassPlayer.bitrate;
  double get levelLeft => _bassPlayer.levelLeft;
  double get levelRight => _bassPlayer.levelRight;
  double get peakLevel => _bassPlayer.peakLevel;

  // 上次采样到的电平值，用于减少不必要的重建
  double _lastLevelLeft = -1.0;
  double _lastLevelRight = -1.0;
  double _lastPeakLevel = -1.0;

  Future<void> seek(Duration position) async {
    // 设置播放器位置
    _bassPlayer.setPosition(position.inMilliseconds / 1000.0);

    // 立即更新本地位置状态，无论播放器是否在播放
    _currentPosition = position;

    // 更新歌词位置
    if (_currentSong != null && _currentSong!.hasLyrics) {
      updateLyric(position);
    }

    // 立即通知UI更新
    notifyListeners();
  }

  MusicProvider() {
    _initBassPlayer();
    _loadInitialData();
    _initAutoScan();
  }

  Future<void> _loadInitialData() async {
    await _loadSongs();
    await _loadHistory();
    await _loadPlaylists();
    await _loadFolders();
  }

  Future<void> addSongsToPlaylist(String playlistId, List<String> songIds) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
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

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final playlistIndex = _playlists.indexWhere((p) => p.id == playlistId);
    if (playlistIndex != -1) {
      final bool removed = _playlists[playlistIndex].songIds.remove(songId);
      if (removed) {
        await _databaseService.updatePlaylist(_playlists[playlistIndex]);
        notifyListeners();
      }
    }
  }

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

  List<Song> getSongsByArtist(String artist) {
    if (_songs.isEmpty) {
      return [];
    }
    return _songs.where((song) => song.artist == artist).toList();
  }

  List<Song> getSongsByAlbum(String album) {
    if (_songs.isEmpty) {
      return [];
    }
    return _songs.where((song) => song.album == album).toList();
  }

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

  List<Song> getMostPlayedSongs({int count = 5}) {
    if (_songs.isEmpty) {
      return [];
    }

    List<Song> sortedSongs = List.from(_songs);
    sortedSongs.sort((a, b) => b.playCount.compareTo(a.playCount));
    return sortedSongs.take(count).toList();
  }

  void setThemeProvider(ThemeProvider themeProvider) {
    _themeProvider = themeProvider;
  }

  Timer? _positionTimer;

  void _initBassPlayer() {
    // 初始化BASS播放器
    if (!_bassPlayer.initialize()) {
      print('BASS播放器初始化失败');
      return;
    }

    // 设置音量
    _bassPlayer.setVolume(_volume);

    // 启动位置更新定时器
    _startPositionTimer();
  }

  void _startPositionTimer() {
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      // 当播放器正在播放时，从播放器获取实际位置
      if (_bassPlayer.isPlaying) {
        final newPosition = Duration(milliseconds: (_bassPlayer.position * 1000).toInt());
        if (newPosition != _currentPosition) {
          _currentPosition = newPosition;

          // 更新总时长
          final newDuration = Duration(milliseconds: (_bassPlayer.length * 1000).toInt());
          if (newDuration != _totalDuration) {
            _totalDuration = newDuration;
          }

          if (_currentSong != null && _currentSong!.hasLyrics) {
            updateLyric(_currentPosition);
          }

          notifyListeners();
        }

        // 电平是瞬态值，即使位置未变也可能更新；当变化明显时再通知UI
        final ll = _bassPlayer.levelLeft;
        final lr = _bassPlayer.levelRight;
        final pk = _bassPlayer.peakLevel;
        bool levelChanged = false;
        const double threshold = 0.02; // 2% 变化阈值
        if ((_lastLevelLeft - ll).abs() > threshold) {
          _lastLevelLeft = ll;
          levelChanged = true;
        }
        if ((_lastLevelRight - lr).abs() > threshold) {
          _lastLevelRight = lr;
          levelChanged = true;
        }
        if ((_lastPeakLevel - pk).abs() > threshold) {
          _lastPeakLevel = pk;
          levelChanged = true;
        }
        if (levelChanged) {
          notifyListeners();
        }

        // 检查是否播放完成（给予0.5秒的容差）
        if (_bassPlayer.position >= (_bassPlayer.length - 0.5) && _bassPlayer.length > 0) {
          timer.cancel();
          if (_currentSong != null) {
            _databaseService.incrementPlayCount(_currentSong!.id);
            _addSongToHistory(_currentSong!);
          }
          _onSongComplete();
        }
      } else {
        // 即使在暂停状态下，也要更新总时长（如果可用）
        final newDuration = Duration(milliseconds: (_bassPlayer.length * 1000).toInt());
        if (newDuration != _totalDuration && newDuration.inSeconds > 0) {
          _totalDuration = newDuration;
          notifyListeners();
        }
        // 暂停时电平基本为0，不必频繁刷新
      }
    });
  }

  Future<void> _loadSongs() async {
    _songs = await _databaseService.getAllSongs();
    _folders = await _databaseService.getAllFolders();
    sortSongs(_sortType);
  }

  Future<void> _loadPlaylists() async {
    final playlistMaps = await _databaseService.getAllPlaylists();
    _playlists = playlistMaps.map((map) {
      List<String> loadedSongIds = [];
      if (map['songIds'] != null && map['songIds'] is List) {
        loadedSongIds = (map['songIds'] as List).map((item) => item.toString()).toList();
      }
      return Playlist(
        id: map['id'] as String,
        name: map['name'] as String,
        songIds: loadedSongIds,
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
      fp.FilePickerResult? result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
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
    File file = File(filePath);
    String fileName = file.uri.pathSegments.last;
    String fileExtension = fileName.split('.').last.toLowerCase();

    List<String> supportedFormats = ['mp3', 'flac', 'wav', 'aac', 'm4a', 'ogg', 'wma'];
    if (!supportedFormats.contains(fileExtension)) {
      return;
    }

    String title = '';
    String artist = '';
    String album = 'Unknown Album';
    Uint8List? albumArtData;
    bool hasLyrics = false;
    String? embeddedLyrics;
    Duration songDuration = Duration.zero;
    DateTime? createdDate;
    DateTime? modifiedDate;
    try {
      final fileMetadata = await FileMetadataUtils.getFileMetadata(filePath);
      createdDate = fileMetadata.createdDate;
      modifiedDate = fileMetadata.modifiedDate;

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
        }
      }

      if (title.isEmpty) {
        final titleAndArtist = _extractTitleAndArtist(filePath, null);
        title = titleAndArtist['title']!;
        artist = titleAndArtist['artist']!;
      }
      if (title.isEmpty) {
        title = fileName.substring(0, fileName.lastIndexOf('.'));
      }

      if (!hasLyrics) {
        String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          hasLyrics = true;
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
        createdDate: createdDate,
        modifiedDate: modifiedDate,
      );

      await _databaseService.insertSong(song);
    } catch (e) {
      try {
        final fileMetadata = await FileMetadataUtils.getFileMetadata(filePath);
        createdDate = fileMetadata.createdDate;
        modifiedDate = fileMetadata.modifiedDate;
      } catch (statError) {
        final now = DateTime.now();
        createdDate = now;
        modifiedDate = now;
      }

      final titleAndArtist = _extractTitleAndArtist(filePath, null);
      title = titleAndArtist['title']!;
      artist = titleAndArtist['artist']!;

      if (title.isEmpty) {
        title = fileName.substring(0, fileName.lastIndexOf('.'));
      }

      if (!hasLyrics) {
        String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          hasLyrics = true;
        }
      }
      Song song = Song(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        artist: artist,
        album: 'Unknown Album',
        filePath: filePath,
        duration: Duration.zero,
        albumArt: null,
        hasLyrics: hasLyrics,
        embeddedLyrics: null,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
      );
      await _databaseService.insertSong(song);
    }
  }

  Future<void> playSong(Song song, {int? index}) async {
    if (_playQueue.isEmpty) {
      if (_repeatMode == RepeatMode.playlistLoop) {
        return;
      }
      _playQueue.add(song);
      _currentIndex = 0;
    } else {
      int foundIndex = _playQueue.indexWhere((s) => s.id == song.id);

      if (index != null && index >= 0 && index < _playQueue.length && _playQueue[index].id == song.id) {
        _currentIndex = index;
      } else if (foundIndex != -1) {
        _currentIndex = foundIndex;
      } else {
        if (_repeatMode == RepeatMode.playlistLoop) {
          _playQueue.add(song);
          _currentIndex = _playQueue.length - 1;
        } else {
          _playQueue.add(song);
          _currentIndex = _playQueue.length - 1;
        }
      }
    }

    _currentSong = song;

    if (_currentIndex < 0 || _currentIndex >= _playQueue.length) {
      await stop();
      _currentSong = null;
      notifyListeners();
      return;
    }

    notifyListeners();

    await Future.wait([
      _playAudio(song),
      _updateThemeAsync(song),
      _loadLyricsAsync(song),
      _updatePlayHistoryAsync(song),
    ]);
  }

  Future<void> _playAudio(Song song) async {
    try {
      // 停止当前播放
      _bassPlayer.stop();

      // 重置位置和歌词
      _currentPosition = Duration.zero;
      _currentLyricIndex = -1;

      // 加载新文件
      if (_bassPlayer.loadFile(song.filePath)) {
        // 获取并设置总时长
        final length = _bassPlayer.length;
        if (length > 0) {
          _totalDuration = Duration(milliseconds: (length * 1000).toInt());
        }

        // 开始播放
        if (_bassPlayer.play()) {
          _playerState = PlayerState.playing;
          _startPositionTimer(); // 重新启动位置定时器
        } else {
          _playerState = PlayerState.stopped;
          print('无法播放文件: ${song.filePath}');
        }
      } else {
        _playerState = PlayerState.stopped;
        print('无法加载文件: ${song.filePath}');
      }
    } catch (e) {
      print('播放音频时出错: $e');
      _playerState = PlayerState.stopped;
    }
  }

  Future<void> _updateThemeAsync(Song song) async {
    if (_themeProvider != null && song.albumArt != null) {
      await _themeProvider!.updateThemeFromAlbumArt(song.albumArt);
    } else if (_themeProvider != null) {
      _themeProvider!.resetToDefault();
    }
  }

  Future<void> _loadLyricsAsync(Song song) async {
    if (song.hasLyrics) {
      await loadLyrics(song);
    } else {
      _lyrics = [];
      _currentLyricIndex = -1;
      notifyListeners();
    }
  }

  Future<void> _updatePlayHistoryAsync(Song song) async {
    _addSongToHistory(song);
    await _databaseService.incrementPlayCount(song.id);
  }

  Future<void> _updatePlayCountOnlyAsync(Song song) async {
    await _databaseService.incrementPlayCount(song.id);
  }

  void _addSongToHistory(Song song) {
    _history.removeWhere((s) => s.id == song.id);
    _history.insert(0, song);

    if (_history.length > 100) {
      _history.removeLast();
    }
    _databaseService.insertHistorySong(song.id);
    notifyListeners();
  }

  void toggleSortDirection() {
    _sortAscending = !_sortAscending;
    sortSongs(_sortType);
  }

  Future<void> removeFromHistory(String songId) async {
    _history.removeWhere((s) => s.id == songId);
    await _databaseService.removeHistorySong(songId);
    notifyListeners();
  }

  Future<void> clearAllHistory() async {
    _history.clear();
    await _databaseService.clearHistory();
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
          break;
        case 'createdDate':
          if (a.createdDate == null && b.createdDate == null) {
            result = 0;
          } else if (a.createdDate == null) {
            result = 1;
          } else if (b.createdDate == null) {
            result = -1;
          } else {
            result = a.createdDate!.compareTo(b.createdDate!);
          }
          break;
        case 'modifiedDate':
          if (a.modifiedDate == null && b.modifiedDate == null) {
            result = 0;
          } else if (a.modifiedDate == null) {
            result = 1;
          } else if (b.modifiedDate == null) {
            result = -1;
          } else {
            result = a.modifiedDate!.compareTo(b.modifiedDate!);
          }
          break;
        default:
          result = a.id.compareTo(b.id);
          break;
      }
      return result * order;
    });
    notifyListeners();
  }

  Future<void> loadLyrics(Song song) async {
    _lyrics = [];
    _currentLyricIndex = -1;
    String? lyricData;

    if (song.embeddedLyrics != null && song.embeddedLyrics!.isNotEmpty) {
      lyricData = song.embeddedLyrics;
    } else {
      String lrcFilePath = '${path.withoutExtension(song.filePath)}.lrc';
      File lrcFile = File(lrcFilePath);
      if (await lrcFile.exists()) {
        lyricData = await lrcFile.readAsString();
      } else {}
    }

    if (lyricData != null) {
      _lyrics = _parseLrcLyrics(lyricData);
      // 加载完成后，依据当前位置立即计算并设置歌词索引，
      // 这样在切歌时即可高亮并聚焦第一行（若当前位置在首句时间戳之前）。
      updateLyric(_currentPosition);
    } else {
      // 无歌词数据，仍通知以刷新UI
      notifyListeners();
    }
  }

  List<LyricLine> _parseLrcLyrics(String lrcData) {
    final List<LyricLine> tempLines = [];

    final RegExp timeTagRegex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\]');

    for (String lineStr in lrcData.split('\n')) {
      String currentLine = lineStr.trim();
      if (currentLine.isEmpty) continue;

      Iterable<RegExpMatch> timeMatches = timeTagRegex.allMatches(currentLine);

      if (!timeMatches.iterator.moveNext()) {
        continue;
      }

      timeMatches = timeTagRegex.allMatches(currentLine);

      String fullLyricText = "";
      int lastTimestampEndIndex = currentLine.lastIndexOf(']');
      if (lastTimestampEndIndex != -1 && lastTimestampEndIndex + 1 < currentLine.length) {
        fullLyricText = currentLine.substring(lastTimestampEndIndex + 1).trim();
      }
      String lyricText = fullLyricText;

      for (RegExpMatch match in timeMatches) {
        int minutes = int.parse(match.group(1)!);
        int seconds = int.parse(match.group(2)!);
        String msPart = match.group(3)!;
        int milliseconds = int.parse(msPart) * (msPart.length == 2 ? 10 : 1);

        Duration timestamp = Duration(minutes: minutes, seconds: seconds, milliseconds: milliseconds);
        tempLines.add(LyricLine(timestamp, lyricText));
      }
    }

    if (tempLines.isEmpty) return [];

    List<MapEntry<int, LyricLine>> indexedLines = [];
    for (int i = 0; i < tempLines.length; i++) {
      indexedLines.add(MapEntry(i, tempLines[i]));
    }

    indexedLines.sort((a, b) {
      int timeComparison = a.value.timestamp.compareTo(b.value.timestamp);
      if (timeComparison != 0) {
        return timeComparison;
      }

      return a.key.compareTo(b.key);
    });

    final List<LyricLine> sortedTempLines = indexedLines.map((entry) => entry.value).toList();

    final List<LyricLine> finalLines = [];
    if (sortedTempLines.isNotEmpty) {
      Map<Duration, List<String>> timestampGroups = {};

      for (LyricLine lyric in sortedTempLines) {
        if (!timestampGroups.containsKey(lyric.timestamp)) {
          timestampGroups[lyric.timestamp] = [];
        }
        timestampGroups[lyric.timestamp]!.add(lyric.text);
      }

      List<Duration> sortedTimestamps = timestampGroups.keys.toList()..sort();

      for (Duration timestamp in sortedTimestamps) {
        List<String> texts = timestampGroups[timestamp]!;

        if (texts.length == 1) {
          finalLines.add(LyricLine(timestamp, texts[0]));
        } else {
          String combinedText = texts.join('\n');
          finalLines.add(LyricLine(timestamp, combinedText));
        }
      }
    }

    return finalLines;
  }

  void updateLyric(Duration currentPosition) {
    if (_lyrics.isEmpty) {
      if (_currentLyricIndex != -1) {
        _currentLyricIndex = -1;
        notifyListeners();
      }
      return;
    }
    // 若当前位置早于第一句时间戳，则将索引固定为 0，
    // 以便在开头阶段也能高亮第一句并让界面聚焦到它。
    int newLyricIndex;
    if (currentPosition < _lyrics.first.timestamp) {
      newLyricIndex = 0;
    } else {
      newLyricIndex = _findLyricIndexForScrolling(currentPosition);
    }

    if (newLyricIndex != _currentLyricIndex) {
      _currentLyricIndex = newLyricIndex;
      notifyListeners();
    }
  }

  int _findLyricIndexForScrolling(Duration currentPosition) {
    if (_lyrics.isEmpty) return -1;

    int left = 0;
    int right = _lyrics.length - 1;
    int result = -1;

    while (left <= right) {
      int mid = (left + right) ~/ 2;
      if (_lyrics[mid].timestamp <= currentPosition) {
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
      _bassPlayer.pause();
      _playerState = PlayerState.paused;
      // 注意：我们不再取消定时器，让它继续运行以处理时长更新
    } else if (_playerState == PlayerState.paused) {
      // 在恢复播放前，确保播放器位置与UI位置同步
      _bassPlayer.setPosition(_currentPosition.inMilliseconds / 1000.0);
      _bassPlayer.play();
      _playerState = PlayerState.playing;
      // 如果定时器没有运行，则启动它
      if (_positionTimer == null || !_positionTimer!.isActive) {
        _startPositionTimer();
      }
    }
    notifyListeners();
  }

  Future<void> stop() async {
    _bassPlayer.stop();
    _playerState = PlayerState.stopped;
    _currentPosition = Duration.zero;
    _currentLyricIndex = -1; // 重置歌词索引
    _positionTimer?.cancel(); // 停止时取消定时器
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    // 设置播放器位置
    _bassPlayer.setPosition(position.inMilliseconds / 1000.0);

    // 立即更新本地位置状态，无论播放器是否在播放
    _currentPosition = position;

    // 更新歌词位置
    if (_currentSong != null && _currentSong!.hasLyrics) {
      updateLyric(position);
    }

    // 立即通知UI更新
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    try {
      double newVolume = volume.clamp(0.0, 1.0);

      if (newVolume > 0) {
        _volumeBeforeMute = newVolume;
      }
      _volume = newVolume;
      notifyListeners();
    } catch (e) {
      print('Error setting volume: $e');
    }
    _bassPlayer.setVolume(_volume);
    notifyListeners();
  }

  Future<void> toggleMute() async {
    if (_volume > 0) {
      _volumeBeforeMute = _volume;
      await setVolume(0.0);
    } else {
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

  Future<void> toggleDesktopLyricMode() async {
    _isDesktopLyricMode = !_isDesktopLyricMode;

    notifyListeners();
  }

  Future<void> nextSong() async {
    if (_playQueue.isEmpty) return;

    try {
      _ensureFullLibraryInQueue();

      int newIndex;
      if (_repeatMode == RepeatMode.randomPlay) {
        if (_playQueue.length > 1) {
          do {
            newIndex = (DateTime.now().millisecondsSinceEpoch % _playQueue.length);
          } while (newIndex == _currentIndex && _playQueue.length > 1);
        } else {
          newIndex = 0;
        }
      } else {
        // 对于其他模式，都使用循环逻辑
        newIndex = (_currentIndex + 1) % _playQueue.length;
      }

      if (newIndex >= 0 && newIndex < _playQueue.length) {
        _currentIndex = newIndex;
        await _playSongFromStart(_playQueue[_currentIndex]);
      } else {
        // 如果索引无效，回到第一首歌
        if (_playQueue.isNotEmpty) {
          _currentIndex = 0;
          await _playSongFromStart(_playQueue[_currentIndex]);
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
      _ensureFullLibraryInQueue();

      int newIndex;
      if (_repeatMode == RepeatMode.randomPlay) {
        // 在随机模式下，尝试从历史记录中获取上一首歌
        if (_history.length > 1) {
          int currentHistoryIndex = _history.indexWhere((s) => s.id == _currentSong?.id);

          if (currentHistoryIndex != -1 && currentHistoryIndex < _history.length - 1) {
            Song previousSong = _history[currentHistoryIndex + 1];
            // 使用不更新历史的方法播放上一首，避免改变随机播放信息/历史顺序
            await _playSongWithoutHistory(previousSong);
            return;
          }
        }

        // 如果没有历史记录，随机选择一首不同的歌
        if (_playQueue.length > 1) {
          do {
            newIndex = (DateTime.now().millisecondsSinceEpoch % _playQueue.length);
          } while (newIndex == _currentIndex && _playQueue.length > 1);
        } else {
          newIndex = 0;
        }
      } else {
        // 对于其他模式，都使用循环逻辑
        newIndex = (_currentIndex - 1 + _playQueue.length) % _playQueue.length;
      }

      if (newIndex >= 0 && newIndex < _playQueue.length) {
        _currentIndex = newIndex;
        await _playSongFromStart(_playQueue[_currentIndex]);
      } else {
        // 如果索引无效，回到第一首歌
        if (_playQueue.isNotEmpty) {
          _currentIndex = 0;
          await _playSongFromStart(_playQueue[_currentIndex]);
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

  Future<void> playSongWithoutHistory(Song song, {int? index}) async {
    await _playSongWithoutHistory(song, index: index);
  }

  Future<void> _playSongWithoutHistory(Song song, {int? index}) async {
    if (_playQueue.isEmpty) {
      _playQueue.add(song);
      _currentIndex = 0;
    } else {
      int foundIndex = _playQueue.indexWhere((s) => s.id == song.id);

      if (index != null && index >= 0 && index < _playQueue.length && _playQueue[index].id == song.id) {
        _currentIndex = index;
      } else if (foundIndex != -1) {
        _currentIndex = foundIndex;
      } else {
        _playQueue.add(song);
        _currentIndex = _playQueue.length - 1;
      }
    }

    _currentSong = song;

    if (_currentIndex < 0 || _currentIndex >= _playQueue.length) {
      await stop();
      _currentSong = null;
      notifyListeners();
      return;
    }

    notifyListeners();

    await Future.wait([
      _playAudio(song),
      _updateThemeAsync(song),
      _loadLyricsAsync(song),
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
        // 单曲播放模式：将播放器设为暂停状态，位置重置到开头
        _bassPlayer.stop();
        _playerState = PlayerState.paused;
        _currentPosition = Duration.zero;
        _currentLyricIndex = -1; // 重置歌词索引
        _positionTimer?.cancel();
        notifyListeners();
        break;

      case RepeatMode.randomPlay:
        // 随机播放模式：播放下一首随机歌曲
        if (_playQueue.length > 1) {
          nextSong();
        } else {
          // 如果只有一首歌，暂停在当前位置
          _bassPlayer.pause();
          _playerState = PlayerState.paused;
          notifyListeners();
        }
        break;

      case RepeatMode.singleCycle:
        // 单曲循环模式：重新播放当前歌曲
        _playSongFromStart(_currentSong!);
        break;

      case RepeatMode.playlistLoop:
        // 播放列表循环模式：播放下一首歌曲
        if (_playQueue.length > 1) {
          if (_currentIndex < _playQueue.length - 1) {
            _currentIndex++;
          } else {
            _currentIndex = 0;
          }
          _playSongFromStart(_playQueue[_currentIndex]);
        } else {
          // 如果只有一首歌，重新播放
          _playSongFromStart(_currentSong!);
        }
        break;
    }
  }

  // 辅助方法：从头开始播放歌曲
  Future<void> _playSongFromStart(Song song) async {
    try {
      _currentSong = song;

      // 停止当前播放
      _bassPlayer.stop();

      // 重置位置和歌词
      _currentPosition = Duration.zero;
      _currentLyricIndex = -1;

      // 加载并播放文件
      if (_bassPlayer.loadFile(song.filePath)) {
        // 获取并设置总时长
        final length = _bassPlayer.length;
        if (length > 0) {
          _totalDuration = Duration(milliseconds: (length * 1000).toInt());
        }

        // 开始播放
        if (_bassPlayer.play()) {
          _playerState = PlayerState.playing;
          _startPositionTimer();
          // 播放新歌曲时，将其加入历史记录
          _addSongToHistory(song);
        } else {
          _playerState = PlayerState.stopped;
          print('无法播放文件: ${song.filePath}');
        }
      } else {
        _playerState = PlayerState.stopped;
        print('无法加载文件: ${song.filePath}');
      }

      notifyListeners();

      // 异步加载歌词、更新主题等
      await Future.wait([
        _loadLyricsAsync(song),
        _updateThemeAsync(song),
      ]);
    } catch (e) {
      print('播放歌曲时出错: $e');
      _playerState = PlayerState.stopped;
      notifyListeners();
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

  void setRepeatMode(RepeatMode mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  Future<bool> deleteSong(String songId) async {
    try {
      await _databaseService.deleteSong(songId);

      final songIndex = _songs.indexWhere((song) => song.id == songId);
      if (songIndex != -1) {
        _songs.removeAt(songIndex);

        if (_currentSong?.id == songId) {
          await stop();
          _currentSong = null;
          _currentIndex = -1;
        } else if (_currentSong != null && songIndex < _currentIndex) {
          _currentIndex--;
        }

        if (_songs.isEmpty) {
          await stop();
          _currentSong = null;
          _currentIndex = -1;
        } else if (_currentIndex >= _songs.length) {
          _currentIndex = _songs.length - 1;
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteSongs(List<String> songIds) async {
    try {
      await _databaseService.deleteSongs(songIds);

      bool currentSongWasDeleted = false;
      if (_currentSong != null && songIds.contains(_currentSong!.id)) {
        currentSongWasDeleted = true;
      }

      _songs.removeWhere((song) => songIds.contains(song.id));

      if (currentSongWasDeleted) {
        await stop();
        _currentSong = null;
        _currentIndex = -1;
        if (_songs.isNotEmpty) {}
      } else {
        if (_currentSong != null) {
          final newCurrentIndex = _songs.indexWhere((s) => s.id == _currentSong!.id);
          if (newCurrentIndex != -1) {
            _currentIndex = newCurrentIndex;
          } else {
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

  Future<Map<String, int>> getLibraryStats() async {
    final songCount = await _databaseService.getSongCount();

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
      'flac': flacCount,
      'wav': wavCount,
      'mp3': mp3Count,
      'other': otherCount,
    };
  }

  Future<void> cleanupDatabase() async {
    await _databaseService.cleanupPlaylistSongs();
    await _loadSongs();
    await _loadPlaylists();
  }

  Future<void> refreshLibrary() async {
    await _loadSongs();
  }

  Future<bool> updateSongInfo(Song updatedSong) async {
    try {
      await _databaseService.updateSong(updatedSong);

      final songIndex = _songs.indexWhere((song) => song.id == updatedSong.id);
      if (songIndex != -1) {
        _songs[songIndex] = updatedSong;

        if (_currentSong?.id == updatedSong.id) {
          _currentSong = updatedSong;
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Map<String, String> _extractTitleAndArtist(String filePath, dynamic metadata) {
    String fileName = path.basenameWithoutExtension(filePath);
    return _parseMetadataFromFilename(fileName);
  }

  Map<String, String> _parseMetadataFromFilename(String filename) {
    String title = filename;
    String artist = '';

    String workingFilename = filename.trim();

    List<String> separators = [' - ', ' – ', ' — ', ' | ', '_'];

    for (String separator in separators) {
      if (workingFilename.contains(separator)) {
        List<String> parts = workingFilename.split(separator);
        if (parts.length >= 2) {
          String part1 = parts[0].trim();
          String part2 = parts[1].trim();
          String cleanPart1 = part1;
          if (RegExp(r'^\d+\.\s+').hasMatch(part1)) {
            cleanPart1 = part1.replaceAll(RegExp(r'^\d+\.\s+'), '').trim();
          }

          if (cleanPart1.isNotEmpty && cleanPart1 != part1) {
            title = cleanPart1;
            artist = part2;
          } else if (part1.length < part2.length * 0.6 && !part1.contains(' ')) {
            artist = part1;
            title = part2;
          } else {
            title = part1;
            artist = part2;
          }
          break;
        }
      }
    }

    if (artist.isEmpty && title == filename) {
      RegExp bracketPattern = RegExp(r'^(.+?)\s*[\[\(]([^\[\]\(\)]+)[\]\)](.*)$');
      Match? match = bracketPattern.firstMatch(workingFilename);

      if (match != null) {
        String titlePart = match.group(1)?.trim() ?? '';
        String bracketContent = match.group(2)?.trim() ?? '';
        String remainingPart = match.group(3)?.trim() ?? '';

        if (bracketContent.isNotEmpty && bracketContent.length > 1) {
          title = titlePart + (remainingPart.isNotEmpty ? ' $remainingPart' : '');
          artist = bracketContent;
        }
      }
    }
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    artist = artist.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (title.isEmpty) {
      title = filename;
    }

    return {
      'title': title,
      'artist': artist,
    };
  }

  Future<String?> getDirectoryPath() async {
    try {
      String? selectedDirectory = await fp.FilePicker.platform.getDirectoryPath();
      return selectedDirectory;
    } catch (e) {
      throw Exception('选择文件夹失败: $e');
    }
  }

  Future<void> addMusicFolder() async {
    try {
      final selectedDirectory = await getDirectoryPath();
      if (selectedDirectory != null) {
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

      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final extension = path.extension(entity.path).toLowerCase();
          if (supportedExtensions.contains(extension)) {
            musicFiles.add(entity);
          }
        }
      }

      if (isBackgroundScan) {
        _totalFilesToScan = musicFiles.length;
        _scanProgress = 0;
        notifyListeners();
      }

      for (int i = 0; i < musicFiles.length; i++) {
        final file = musicFiles[i];
        await _processMusicFile(File(file.path));

        if (isBackgroundScan) {
          _scanProgress = i + 1;
          notifyListeners();
        }
      }

      _songs = await _databaseService.getAllSongs();
      notifyListeners();
    } catch (e) {
      throw Exception('扫描文件夹失败: $e');
    }
  }

  Future<void> _processMusicFile(File file) async {
    final filePath = file.path;
    final String fileId = filePath;

    String title = '';
    String artist = '';
    String album = 'Unknown Album';
    Uint8List? albumArtData;
    bool hasLyrics = false;
    String? embeddedLyrics;
    Duration songDuration = Duration.zero;
    DateTime? createdDate;
    DateTime? modifiedDate;

    try {
      final fileMetadata = await FileMetadataUtils.getFileMetadata(filePath);
      createdDate = fileMetadata.createdDate;
      modifiedDate = fileMetadata.modifiedDate;

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
        }
      }

      if (title.isEmpty) {
        final titleAndArtist = _extractTitleAndArtist(filePath, null);
        title = titleAndArtist['title']!;
        artist = titleAndArtist['artist']!;
      }
      final String fileName = path.basename(filePath);
      if (title.isEmpty) {
        title = fileName.substring(0, fileName.lastIndexOf('.') > -1 ? fileName.lastIndexOf('.') : fileName.length);
      }
      if (artist.isEmpty) {
        artist = 'Unknown Artist';
      }

      if (await _databaseService.songExistsByMetadata(title, artist, album)) {
        return;
      }

      if (!hasLyrics) {
        String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          hasLyrics = true;
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
        hasLyrics: hasLyrics,
        embeddedLyrics: embeddedLyrics,
        createdDate: createdDate,
        modifiedDate: modifiedDate,
      );

      await _databaseService.insertSong(song);
    } catch (e) {
      try {
        final fileMetadata = await FileMetadataUtils.getFileMetadata(filePath);
        createdDate = fileMetadata.createdDate;
        modifiedDate = fileMetadata.modifiedDate;
      } catch (dateError) {
        print('获取文件日期失败 (批量处理): $dateError');
        final now = DateTime.now();
        createdDate = now;
        modifiedDate = now;
      }

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

      if (await _databaseService.songExistsByMetadata(title, artist, album)) {
        return;
      }

      if (!hasLyrics) {
        String lrcFilePath = '${path.withoutExtension(filePath)}.lrc';
        File lrcFile = File(lrcFilePath);
        if (await lrcFile.exists()) {
          hasLyrics = true;
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
        createdDate: createdDate,
        modifiedDate: modifiedDate,
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

  Future<void> createPlaylist(String name) async {
    final newPlaylist = Playlist(name: name);
    await _databaseService.insertPlaylist(newPlaylist);
    await _loadPlaylists();
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _databaseService.deletePlaylist(playlistId);
    await _loadPlaylists();
  }

  Future<void> renamePlaylist(String playlistId, String newName) async {
    await _databaseService.renamePlaylist(playlistId, newName);
    await _loadPlaylists();
  }

  Future<void> addSongToPlaylist(String songId, String playlistId) async {
    try {
      await _databaseService.addSongToPlaylist(songId, playlistId);

      await _loadPlaylists();
    } catch (e) {
      throw Exception('添加歌曲到歌单失败: $e');
    }
  }

  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    return await _databaseService.getSongsForPlaylist(playlistId);
  }

  Map<String, List<Song>> findDuplicateSongs() {
    Map<String, List<Song>> duplicateGroups = {};

    for (Song song in _songs) {
      String key = '${song.title.toLowerCase()}_${song.artist.toLowerCase()}_${song.album.toLowerCase()}';

      if (duplicateGroups.containsKey(key)) {
        duplicateGroups[key]!.add(song);
      } else {
        duplicateGroups[key] = [song];
      }
    }

    duplicateGroups.removeWhere((key, songs) => songs.length <= 1);

    return duplicateGroups;
  }

  Future<bool> deleteDuplicateSongs(List<String> songIdsToDelete) async {
    try {
      return await deleteSongs(songIdsToDelete);
    } catch (e) {
      print('Error deleting duplicate songs: $e');
      return false;
    }
  }

  void _ensureFullLibraryInQueue() {
    if (_repeatMode == RepeatMode.playlistLoop) {
      return;
    }

    if (_playQueue.length != _songs.length) {
      Song? currentPlayingSong = _currentSong;

      _playQueue.clear();
      _playQueue.addAll(_songs);

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

  void addToPlayQueue(Song song) {
    if (!_playQueue.any((s) => s.id == song.id)) {
      _playQueue.add(song);
      notifyListeners();
    }
  }

  void addMultipleToPlayQueue(List<Song> songs) {
    for (Song song in songs) {
      if (!_playQueue.any((s) => s.id == song.id)) {
        _playQueue.add(song);
      }
    }
    notifyListeners();
  }

  void removeFromPlayQueue(int index) {
    if (index >= 0 && index < _playQueue.length) {
      if (index == _currentIndex) {
        if (_playQueue.length > 1) {
          if (_currentIndex < _playQueue.length - 1) {
            _playQueue.removeAt(index);

            if (_currentIndex < _playQueue.length) {
              playSong(_playQueue[_currentIndex], index: _currentIndex);
            } else {
              stop();
              _currentSong = null;
              _currentIndex = 0;
            }
          } else {
            _playQueue.removeAt(index);
            if (_playQueue.isNotEmpty) {
              _currentIndex = _playQueue.length - 1;
              playSong(_playQueue[_currentIndex], index: _currentIndex);
            } else {
              stop();
              _currentSong = null;
              _currentIndex = 0;
            }
          }
        } else {
          _playQueue.removeAt(index);
          stop();
          _currentSong = null;
          _currentIndex = 0;
        }
      } else {
        _playQueue.removeAt(index);

        if (index < _currentIndex) {
          _currentIndex--;
        }

        if (_playQueue.isEmpty) {
          stop();
          _currentSong = null;
          _currentIndex = 0;
        }
      }
      notifyListeners();
    }
  }

  void removeMultipleFromPlayQueue(List<int> indices) {
    if (indices.isEmpty) return;

    final sortedIndices = indices.toList()..sort((a, b) => b.compareTo(a));

    bool currentSongWillBeRemoved = false;
    bool allSongsWillBeRemoved = false;

    if (_currentIndex >= 0 && indices.contains(_currentIndex)) {
      currentSongWillBeRemoved = true;
    }

    if (indices.length == _playQueue.length) {
      allSongsWillBeRemoved = true;
    }

    for (final index in sortedIndices) {
      if (index >= 0 && index < _playQueue.length) {
        _playQueue.removeAt(index);

        if (index < _currentIndex) {
          _currentIndex--;
        } else if (index == _currentIndex) {
          _currentIndex = -1;
        }
      }
    }

    if (allSongsWillBeRemoved || _playQueue.isEmpty) {
      stop();
      _currentSong = null;
      _currentIndex = 0;
    } else if (currentSongWillBeRemoved) {
      if (_currentIndex == -1 || _currentIndex >= _playQueue.length) {
        _currentIndex = 0;
      }
      if (_currentIndex < _playQueue.length) {
        playSong(_playQueue[_currentIndex], index: _currentIndex);
      }
    }

    notifyListeners();
  }

  void clearPlayQueue() {
    _playQueue.clear();
    stop();
    _currentSong = null;
    _currentIndex = 0;
    notifyListeners();
  }

  void playAllSongs() {
    if (_songs.isEmpty) return;

    _playQueue.clear();

    _playQueue.addAll(_songs);

    _repeatMode = RepeatMode.playlistLoop;

    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  void playPlaylist(Playlist playlist) {
    if (playlist.songIds.isEmpty) return;

    final playlistSongs = _songs.where((song) => playlist.songIds.contains(song.id)).toList();

    playlistSongs.sort((a, b) => playlist.songIds.indexOf(a.id).compareTo(playlist.songIds.indexOf(b.id)));

    if (playlistSongs.isEmpty) return;

    _playQueue.clear();

    _playQueue.addAll(playlistSongs);

    _repeatMode = RepeatMode.playlistLoop;

    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  void playAllByArtist(String artist) {
    if (_songs.isEmpty || artist.isEmpty) return;

    final artistSongs = _songs.where((song) => song.artist == artist).toList();

    if (artistSongs.isEmpty) return;

    _playQueue.clear();

    _playQueue.addAll(artistSongs);

    _repeatMode = RepeatMode.playlistLoop;

    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  void playAllByAlbum(String album, String artist) {
    if (_songs.isEmpty || album.isEmpty) return;

    final albumSongs = _songs.where((song) => song.album == album && song.artist == artist).toList();

    albumSongs.sort((a, b) => a.title.compareTo(b.title));

    if (albumSongs.isEmpty) return;

    _playQueue.clear();

    _playQueue.addAll(albumSongs);

    _repeatMode = RepeatMode.playlistLoop;

    if (_playQueue.isNotEmpty) {
      playFromQueue(0);
    }

    notifyListeners();
  }

  void reorderPlayQueue(int oldIndex, int newIndex) {
    if (oldIndex < _playQueue.length && newIndex < _playQueue.length) {
      final Song song = _playQueue.removeAt(oldIndex);
      _playQueue.insert(newIndex, song);

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

  Future<void> playFromQueue(int index) async {
    if (index >= 0 && index < _playQueue.length) {
      _currentIndex = index;
      await playSong(_playQueue[index], index: index);
    }
  }

  void _initAutoScan() {
    _startAutoScanTimer();
  }

  void _startAutoScanTimer() {
    _autoScanTimer?.cancel();
    _autoScanTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _performScheduledScan();
    });
  }

  Future<void> _performScheduledScan() async {
    if (_isAutoScanning) return;

    final now = DateTime.now();
    final autoScanFolders = _folders
        .where((folder) =>
            folder.isAutoScan && (folder.lastScanTime == null || now.difference(folder.lastScanTime!).inMinutes >= folder.scanIntervalMinutes))
        .toList();

    if (autoScanFolders.isNotEmpty) {
      await _scanFoldersInBackground(autoScanFolders);
    }
  }

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

      Timer(const Duration(seconds: 3), () {
        _currentScanStatus = '';
        notifyListeners();
      });
    }
  }

  Future<void> _updateFolderLastScanTime(String folderId) async {
    try {
      final folder = _folders.firstWhere((f) => f.id == folderId);
      final updatedFolder = folder.copyWith(lastScanTime: DateTime.now());
      await _databaseService.updateFolder(updatedFolder);

      final index = _folders.indexWhere((f) => f.id == folderId);
      if (index != -1) {
        _folders[index] = updatedFolder;
      }
    } catch (e) {
      print('更新文件夹扫描时间失败: $e');
    }
  }

  void stopAutoScan() {
    _autoScanTimer?.cancel();
    _isAutoScanning = false;
    notifyListeners();
  }

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
    _positionTimer?.cancel();
    for (final subscription in _fileWatchers.values) {
      subscription.cancel();
    }
    _fileWatchers.clear();
    _bassPlayer.dispose();
    super.dispose();
  }
}
