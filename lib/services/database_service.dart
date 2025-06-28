import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'dart:io';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  // 添加缓存机制
  List<Song>? _cachedSongs;
  DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5); // 缓存5分钟

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // 新增：检查缓存是否有效
  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;
  }

  // 新增：清除缓存
  void _clearCache() {
    _cachedSongs = null;
    _lastCacheTime = null;
  }

  Future<Database> _initDatabase() async {
    // 初始化桌面平台的数据库工厂
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      // 初始化 FFI
      sqfliteFfiInit();
      // 设置全局工厂
      databaseFactory = databaseFactoryFfi;
    }

    String databasesPath;
    if (Platform.isAndroid || Platform.isIOS) {
      databasesPath = await getDatabasesPath();
    } else {
      // 对于桌面平台，使用应用程序文档目录
      final appDocDir = await getApplicationDocumentsDirectory();
      databasesPath = appDocDir.path;
    }
    String path = join(databasesPath, 'music_player.db');

    return await openDatabase(
      path,
      version: 9, // Incremented database version to ensure history table creation
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE songs(
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        filePath TEXT NOT NULL,
        duration INTEGER NOT NULL,
        albumArt BLOB,
        playCount INTEGER NOT NULL DEFAULT 0,
        hasLyrics INTEGER NOT NULL DEFAULT 0,
        embeddedLyrics TEXT 
      )
    ''');

    await db.execute('''
      CREATE TABLE folders(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        isAutoScan INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE history(
        songId TEXT NOT NULL,
        playedAt TEXT NOT NULL,
        FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE,
        PRIMARY KEY (songId, playedAt) 
      )
    ''');

    await db.execute('''
      CREATE TABLE playlists(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs(
        playlistId TEXT NOT NULL,
        songId TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlistId, songId),
        FOREIGN KEY (playlistId) REFERENCES playlists(id) ON DELETE CASCADE,
        FOREIGN KEY (songId) REFERENCES songs(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('DROP TABLE IF EXISTS songs');
      await db.execute('''
        CREATE TABLE songs(
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          artist TEXT NOT NULL,
          album TEXT NOT NULL,
          filePath TEXT NOT NULL,
          duration INTEGER NOT NULL,
          albumArt BLOB,
          playCount INTEGER NOT NULL DEFAULT 0,
          hasLyrics INTEGER NOT NULL DEFAULT 0,
          embeddedLyrics TEXT 
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS folders(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          path TEXT NOT NULL,
          isAutoScan INTEGER NOT NULL DEFAULT 1,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 4) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool playCountExists = tableInfo.any((column) => column['name'] == 'playCount');
      if (!playCountExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN playCount INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 5) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool hasLyricsExists = tableInfo.any((column) => column['name'] == 'hasLyrics');
      if (!hasLyricsExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN hasLyrics INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 6) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool embeddedLyricsExists = tableInfo.any((column) => column['name'] == 'embeddedLyrics');
      if (!embeddedLyricsExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN embeddedLyrics TEXT');
      }
    }
    // For version 8, we add the history table and update foreign keys.
    if (oldVersion < 8) {
      // Add history table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS history(
          songId TEXT NOT NULL,
          playedAt TEXT NOT NULL,
          FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE,
          PRIMARY KEY (songId, playedAt)
        )
      ''');
    }

    // Ensure history table exists if upgrading to version 9 (covers broken v8 state)
    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS history(
          songId TEXT NOT NULL,
          playedAt TEXT NOT NULL,
          FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE,
          PRIMARY KEY (songId, playedAt)
        )
      ''');
    }
  }

  Future<void> insertSong(Song song) async {
    final db = await database;
    await db.insert(
      'songs',
      song.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // 清除缓存，确保下次查询获取最新数据
    _clearCache();
  }

  Future<List<Song>> getAllSongs() async {
    // 检查缓存是否有效
    if (_isCacheValid() && _cachedSongs != null) {
      return _cachedSongs!;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('songs');

    final songs = List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });

    // 更新缓存
    _cachedSongs = songs;
    _lastCacheTime = DateTime.now();

    return songs;
  }

  // New method to increment play count
  Future<void> incrementPlayCount(String songId) async {
    final db = await database;
    // 使用原生SQL进行更高效的更新
    await db.rawUpdate('''
      UPDATE songs 
      SET playCount = playCount + 1 
      WHERE id = ?
    ''', [songId]);

    // 更新缓存中的播放次数
    if (_cachedSongs != null) {
      final songIndex = _cachedSongs!.indexWhere((song) => song.id == songId);
      if (songIndex != -1) {
        _cachedSongs![songIndex] = _cachedSongs![songIndex].copyWith(
          playCount: _cachedSongs![songIndex].playCount + 1,
        );
      }
    }
  }

  Future<void> deleteSong(String id) async {
    final db = await database;
    await db.delete('songs', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSong(Song song) async {
    final db = await database;
    await db.update(
      'songs',
      song.toMap(),
      where: 'id = ?',
      whereArgs: [song.id],
    );
  }

  // 批量删除歌曲
  Future<void> deleteSongs(List<String> ids) async {
    final db = await database;
    final batch = db.batch();

    for (String id in ids) {
      batch.delete('songs', where: 'id = ?', whereArgs: [id]);
    }

    await batch.commit();
  }

  // 获取歌曲总数
  Future<int> getSongCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 获取文件夹总数
  Future<int> getFolderCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM folders');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Stub methods for folder and song existence checks (to be fully implemented if needed)
  Future<List<MusicFolder>> getAllFolders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('folders');
    return List.generate(maps.length, (i) {
      return MusicFolder.fromMap(maps[i]);
    });
  }

  Future<bool> folderExists(String path) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'folders',
      where: 'path = ?',
      whereArgs: [path],
    );
    return result.isNotEmpty;
  }

  Future<void> insertFolder(MusicFolder folder) async {
    final db = await database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteFolder(String id) async {
    final db = await database;
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateFolder(MusicFolder folder) async {
    final db = await database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<bool> songExists(String filePath) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'songs',
      where: 'filePath = ?',
      whereArgs: [filePath],
    );
    return result.isNotEmpty;
  }

  // History methods
  Future<void> insertHistorySong(String songId) async {
    final db = await database;
    // Remove any existing entries for this song to ensure it's "moved to top" if played again,
    // then insert the new play instance.
    // await db.delete('history', where: 'songId = ?', whereArgs: [songId]); // Optional: if you only want one entry per song
    await db.insert(
      'history',
      {
        'songId': songId,
        'playedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Song>> getHistorySongs() async {
    final db = await database;
    final List<Map<String, dynamic>> historyMaps = await db.query(
      'history',
      orderBy: 'playedAt DESC',
    );

    if (historyMaps.isEmpty) {
      return [];
    }

    final songIds = <String>[];
    final playedAtMap = <String, String>{}; // To store the latest playedAt for each songId

    for (var map in historyMaps) {
      final songId = map['songId'] as String;
      final playedAt = map['playedAt'] as String;
      // If we only want the most recent play of each song in the history list
      if (!songIds.contains(songId)) {
        songIds.add(songId);
        playedAtMap[songId] = playedAt;
      }
      // If we want all play instances, just add songId and handle ordering later or by fetching all and then processing.
      // For now, let's get unique songs ordered by their *last* play time.
    }

    if (songIds.isEmpty) return [];

    String placeholders = List.filled(songIds.length, '?').join(',');
    final List<Map<String, dynamic>> songDetailMaps = await db.query(
      'songs',
      where: 'id IN ($placeholders)',
      whereArgs: songIds,
    );

    List<Song> songs = songDetailMaps.map((map) => Song.fromMap(map)).toList();

    // Sort songs based on the playedAt time from historyMap
    songs.sort((a, b) {
      DateTime? playedAtA = DateTime.tryParse(playedAtMap[a.id] ?? '');
      DateTime? playedAtB = DateTime.tryParse(playedAtMap[b.id] ?? '');
      if (playedAtA == null && playedAtB == null) return 0;
      if (playedAtA == null) return 1; // Put songs with no playedAt (should not happen) at the end
      if (playedAtB == null) return -1;
      return playedAtB.compareTo(playedAtA); // Descending order
    });

    return songs;
  }

  Future<void> clearHistory() async {
    final db = await database;
    await db.delete('history');
  }

  Future<void> removeHistorySong(String songId) async {
    final db = await database;
    await db.delete('history', where: 'songId = ?', whereArgs: [songId]);
  }

  // 播放列表相关方法
  Future<void> insertPlaylist(Playlist playlist) async {
    final db = await database;
    await db.insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'createdAt': DateTime.now().toIso8601String(), // Add createdAt timestamp
    });
  }

  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final db = await database;

    // Get all playlists
    final playlists = await db.query('playlists', orderBy: 'createdAt DESC');

    // For each playlist, get its songs
    List<Map<String, dynamic>> playlistsWithSongs = [];
    for (final playlist in playlists) {
      final playlistId = playlist['id'] as String;

      // Get song IDs for this playlist ordered by position
      final songIds = await db.query(
        'playlist_songs',
        columns: ['songId'],
        where: 'playlistId = ?',
        whereArgs: [playlistId],
        orderBy: 'position ASC',
      );

      // Extract songIds as List<String>
      final songIdList = songIds.map((row) => row['songId'] as String).toList();

      // Add songIds to the playlist map
      final playlistWithSongs = Map<String, dynamic>.from(playlist);
      playlistWithSongs['songIds'] = songIdList;
      playlistsWithSongs.add(playlistWithSongs);
    }

    return playlistsWithSongs;
  }

  Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    // Also delete associated songs from playlist_songs table
    await db.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [id]);
  }

  Future<void> renamePlaylist(String id, String newName) async {
    final db = await database;
    await db.update(
      'playlists',
      {'name': newName},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Add this method to update a playlist, including its songs
  Future<void> updatePlaylist(Playlist playlist) async {
    final db = await database;
    await db.transaction((txn) async {
      // Update playlist name (if necessary, though typically handled by renamePlaylist)
      await txn.update(
        'playlists',
        {'name': playlist.name},
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      // Clear existing songs for this playlist
      await txn.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [playlist.id]);

      // Add current songs to the playlist
      for (int i = 0; i < playlist.songIds.length; i++) {
        await txn.insert('playlist_songs', {
          'playlistId': playlist.id,
          'songId': playlist.songIds[i],
          'position': i,
        });
      }
    });
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final db = await database;
    // Get current max position for the playlist
    final result = await db.rawQuery('SELECT MAX(position) as max_position FROM playlist_songs WHERE playlistId = ?', [playlistId]);
    int position = 0;
    if (result.isNotEmpty && result.first['max_position'] != null) {
      position = (result.first['max_position'] as int) + 1;
    }
    await db.insert(
        'playlist_songs',
        {
          'playlistId': playlistId,
          'songId': songId,
          'position': position, // Add position
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final db = await database;
    await db.delete('playlist_songs', where: 'playlistId = ? AND songId = ?', whereArgs: [playlistId, songId]);
  }

  Future<List<Song>> getSongsForPlaylist(String playlistId) async {
    final db = await database;
    final List<Map<String, dynamic>> playlistSongMaps = await db.query(
      'playlist_songs',
      where: 'playlistId = ?',
      whereArgs: [playlistId],
      orderBy: 'position ASC',
    );

    if (playlistSongMaps.isEmpty) {
      return [];
    }

    final songIds = playlistSongMaps.map((map) => map['songId'] as String).toList();
    if (songIds.isEmpty) return [];

    String placeholders = List.filled(songIds.length, '?').join(',');
    final List<Map<String, dynamic>> songDetailMaps = await db.query(
      'songs',
      where: 'id IN ($placeholders)',
      whereArgs: songIds,
    );

    // Create a map of song details for easy lookup
    final songDetailsById = {for (var map in songDetailMaps) map['id'] as String: Song.fromMap(map)};

    // Reconstruct the list of songs in the correct order from playlist_songs
    List<Song> songs = [];
    for (String songId in songIds) {
      if (songDetailsById.containsKey(songId)) {
        songs.add(songDetailsById[songId]!);
      }
    }
    return songs;
  }

  // Method to clean up orphaned playlist_songs entries (optional, but good practice)
  Future<void> cleanupPlaylistSongs() async {
    final db = await database;
    // Delete playlist_songs entries where the songId no longer exists in the songs table
    await db.rawDelete('''
      DELETE FROM playlist_songs
      WHERE songId NOT IN (SELECT id FROM songs)
    ''');
    // Delete playlist_songs entries where the playlistId no longer exists in the playlists table
    await db.rawDelete('''
      DELETE FROM playlist_songs
      WHERE playlistId NOT IN (SELECT id FROM playlists)
    ''');
  }

  // New method to delete duplicate songs, returns the deleted songs
  Future<List<Song>> deleteDuplicateSongs() async {
    final db = await database;
    // This query selects all data of songs that are considered duplicates.
    // For each group of duplicates (same title, artist, album), it keeps the one
    // with the highest playCount. If playCounts are equal, it keeps the one
    // with the smallest ID (usually the one added first).
    final List<Map<String, dynamic>> duplicateMaps = await db.rawQuery('''
      SELECT * FROM songs
      WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER(PARTITION BY title, artist, album ORDER BY playCount DESC, id ASC) as rn
          FROM songs
        )
        WHERE rn > 1
      )
    ''');

    if (duplicateMaps.isEmpty) {
      return [];
    }

    final List<Song> deletedSongs = duplicateMaps.map((map) => Song.fromMap(map)).toList();
    final idsToDelete = deletedSongs.map((song) => song.id).toList();

    if (idsToDelete.isEmpty) {
      return [];
    }

    // Use a transaction to delete all duplicates at once.
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in idsToDelete) {
        batch.delete('songs', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });

    _clearCache(); // Clear cache after deletion
    return deletedSongs;
  }
}
