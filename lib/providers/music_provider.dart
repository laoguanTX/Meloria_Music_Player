import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart' as audio;
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import '../models/song.dart';
import '../services/database_service.dart';
import 'theme_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as path;

enum PlayerState { stopped, playing, paused }

enum RepeatMode { none, one, all }

class MusicProvider extends ChangeNotifier {
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
        FilePickerResult? result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
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
        print('Error importing music: $e');
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
      print('不支持的音频格式: $fileExtension');
      return;
    }

    // 基础元数据提取 - 去除文件扩展名，保留完整文件名
    String originalTitle = fileName.substring(0, fileName.lastIndexOf('.'));
    String title = '';
    String artist = '';
    String album = 'Unknown Album';
    Uint8List? albumArtData; // 1. 优先读取音乐标签
    try {
      final metadata = readMetadata(file, getImage: true);
      String tagTitle = metadata.title ?? '';
      String tagArtist = metadata.artist ?? '';
      String tagAlbum = metadata.album ?? '';

      // 读取专辑封面数据
      if (metadata.pictures.isNotEmpty) {
        final picture = metadata.pictures.first;
        albumArtData = picture.bytes;
        print('专辑图片读取成功: ${albumArtData.length} bytes for $originalTitle');
      } else {
        print('未找到专辑图片: $originalTitle');
      }

      // 如果标签中有标题和艺术家，优先使用
      if (tagTitle.isNotEmpty && tagArtist.isNotEmpty) {
        title = tagTitle;
        artist = tagArtist;
        album = tagAlbum.isNotEmpty ? tagAlbum : 'Unknown Album';
      }
      // 如果只有标题，没有艺术家
      else if (tagTitle.isNotEmpty) {
        title = tagTitle;
        artist = tagArtist;
        album = tagAlbum.isNotEmpty ? tagAlbum : 'Unknown Album';
      }
      // 如果标签不完整，记录现有信息，后续用文件名补充
      else {
        if (tagTitle.isNotEmpty) title = tagTitle;
        if (tagArtist.isNotEmpty) artist = tagArtist;
        if (tagAlbum.isNotEmpty) album = tagAlbum;
      }
    } catch (e) {
      print('读取音乐标签失败: $e');
      // 标签读取失败，后续用文件名解析
    }

    // 2. 如果标签信息不完整，尝试从文件名解析
    if (title.isEmpty || artist.isEmpty) {
      final parsed = _parseMetadataFromFilename(originalTitle);

      // 只在对应字段为空时才使用解析结果
      if (title.isEmpty) {
        title = parsed['title'] ?? originalTitle;
      }
      if (artist.isEmpty) {
        artist = parsed['artist'] ?? '';
      }
    } // 3. 最终回退策略：如果标题仍为空，使用完整文件名
    if (title.isEmpty) {
      title = originalTitle;
    }

    Song song = Song(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      artist: artist,
      album: album,
      filePath: filePath,
      duration: Duration.zero, // 播放时会自动获取
      albumArt: albumArtData, // 直接使用专辑图片数据，不保存到文件
    );

    await _databaseService.insertSong(song);
  }

  Future<void> playSong(Song song, {int? index}) async {
    try {
      _currentSong = song;
      _currentIndex = index ?? _songs.indexOf(song);

      print('播放歌曲: ${song.title}');
      print(
          '专辑图片数据: ${song.albumArt != null ? '${song.albumArt!.length} bytes' : '无'}');

      // 更新主题颜色
      if (_themeProvider != null) {
        await _themeProvider!.updateThemeFromAlbumArt(song.albumArt);
      }

      await _audioPlayer.play(audio.DeviceFileSource(song.filePath));
      _playerState = PlayerState.playing;
      notifyListeners();
    } catch (e) {
      print('Error playing song: $e');
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
      print('删除歌曲时出错: $e');
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
      print('更新歌曲信息时出错: $e');
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
      String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
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
          print('处理文件失败: ${file.path}, 错误: $e');
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
    final fileId = filePath.hashCode.toString();

    // 检查歌曲是否已存在
    if (await _databaseService.songExists(fileId)) {
      return;
    }

    try {
      final metadata = readMetadata(file, getImage: true);
      final titleAndArtist = _extractTitleAndArtist(filePath, metadata);

      final song = Song(
        id: fileId,
        title: titleAndArtist['title']!,
        artist: titleAndArtist['artist']!,
        album: metadata.album ?? '未知专辑',
        filePath: filePath,
        duration: metadata.duration ?? Duration.zero,
        albumArt:
            metadata.pictures.isNotEmpty ? metadata.pictures.first.bytes : null,
      );

      await _databaseService.insertSong(song);
    } catch (e) {
      print('处理音乐文件元数据失败: $filePath, 错误: $e');
      // 创建基本的歌曲信息
      final titleAndArtist = _extractTitleAndArtist(filePath, null);
      final song = Song(
        id: fileId,
        title: titleAndArtist['title']!,
        artist: titleAndArtist['artist']!,
        album: '未知专辑',
        filePath: filePath,
        duration: Duration.zero,
        albumArt: null,
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

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}
