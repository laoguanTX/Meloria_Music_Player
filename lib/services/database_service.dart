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

  List<Song>? _cachedSongs;
  DateTime? _lastCacheTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!) < _cacheExpiry;
  }

  void _clearCache() {
    _cachedSongs = null;
    _lastCacheTime = null;
  }

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    String databasesPath;
    if (Platform.isAndroid || Platform.isIOS) {
      databasesPath = await getDatabasesPath();
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      databasesPath = appDocDir.path;
    }
    String path = join(databasesPath, 'music_player.db');

    return await openDatabase(
      path,
      version: 12,
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
        embeddedLyrics TEXT,
        createdDate INTEGER,
        modifiedDate INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE folders(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        path TEXT NOT NULL,
        isAutoScan INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        lastScanTime TEXT,
        scanIntervalMinutes INTEGER NOT NULL DEFAULT 30,
        watchFileChanges INTEGER NOT NULL DEFAULT 1
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

    await db.execute('''
      CREATE TABLE user_settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
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
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS history(
          songId TEXT NOT NULL,
          playedAt TEXT NOT NULL,
          FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE,
          PRIMARY KEY (songId, playedAt)
        )
      ''');
    }
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

    if (oldVersion < 10) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(folders)");

      bool lastScanTimeExists = tableInfo.any((column) => column['name'] == 'lastScanTime');
      if (!lastScanTimeExists) {
        await db.execute('ALTER TABLE folders ADD COLUMN lastScanTime TEXT');
      }

      bool scanIntervalMinutesExists = tableInfo.any((column) => column['name'] == 'scanIntervalMinutes');
      if (!scanIntervalMinutesExists) {
        await db.execute('ALTER TABLE folders ADD COLUMN scanIntervalMinutes INTEGER NOT NULL DEFAULT 30');
      }

      bool watchFileChangesExists = tableInfo.any((column) => column['name'] == 'watchFileChanges');
      if (!watchFileChangesExists) {
        await db.execute('ALTER TABLE folders ADD COLUMN watchFileChanges INTEGER NOT NULL DEFAULT 1');
      }
    }

    if (oldVersion < 11) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");

      bool createdDateExists = tableInfo.any((column) => column['name'] == 'createdDate');
      if (!createdDateExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN createdDate INTEGER');
      }

      bool modifiedDateExists = tableInfo.any((column) => column['name'] == 'modifiedDate');
      if (!modifiedDateExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN modifiedDate INTEGER');
      }
    }

    if (oldVersion < 12) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS user_settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
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

    _clearCache();
  }

  Future<List<Song>> getAllSongs() async {
    if (_isCacheValid() && _cachedSongs != null) {
      return _cachedSongs!;
    }

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('songs');

    final songs = List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });

    _cachedSongs = songs;
    _lastCacheTime = DateTime.now();

    return songs;
  }

  // New method to increment play count
  Future<void> incrementPlayCount(String songId) async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE songs 
      SET playCount = playCount + 1 
      WHERE id = ?
    ''', [songId]);

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

  Future<void> deleteSongs(List<String> ids) async {
    final db = await database;
    final batch = db.batch();

    for (String id in ids) {
      batch.delete('songs', where: 'id = ?', whereArgs: [id]);
    }

    await batch.commit();
  }

  Future<int> getSongCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> getFolderCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM folders');
    return Sqflite.firstIntValue(result) ?? 0;
  }

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

  Future<bool> songExistsByMetadata(String title, String artist, String album) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'songs',
      where: 'title = ? AND artist = ? AND album = ?',
      whereArgs: [title, artist, album],
    );
    return result.isNotEmpty;
  }

  Future<void> insertHistorySong(String songId) async {
    final db = await database;
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
    final playedAtMap = <String, String>{};

    for (var map in historyMaps) {
      final songId = map['songId'] as String;
      final playedAt = map['playedAt'] as String;
      if (!songIds.contains(songId)) {
        songIds.add(songId);
        playedAtMap[songId] = playedAt;
      }
    }

    if (songIds.isEmpty) return [];

    String placeholders = List.filled(songIds.length, '?').join(',');
    final List<Map<String, dynamic>> songDetailMaps = await db.query(
      'songs',
      where: 'id IN ($placeholders)',
      whereArgs: songIds,
    );

    List<Song> songs = songDetailMaps.map((map) => Song.fromMap(map)).toList();

    songs.sort((a, b) {
      DateTime? playedAtA = DateTime.tryParse(playedAtMap[a.id] ?? '');
      DateTime? playedAtB = DateTime.tryParse(playedAtMap[b.id] ?? '');
      if (playedAtA == null && playedAtB == null) return 0;
      if (playedAtA == null) return 1;
      if (playedAtB == null) return -1;
      return playedAtB.compareTo(playedAtA);
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

  Future<void> insertPlaylist(Playlist playlist) async {
    final db = await database;
    await db.insert('playlists', {
      'id': playlist.id,
      'name': playlist.name,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getAllPlaylists() async {
    final db = await database;

    final playlists = await db.query('playlists', orderBy: 'createdAt DESC');

    List<Map<String, dynamic>> playlistsWithSongs = [];
    for (final playlist in playlists) {
      final playlistId = playlist['id'] as String;

      final songIds = await db.query(
        'playlist_songs',
        columns: ['songId'],
        where: 'playlistId = ?',
        whereArgs: [playlistId],
        orderBy: 'position ASC',
      );

      final songIdList = songIds.map((row) => row['songId'] as String).toList();

      final playlistWithSongs = Map<String, dynamic>.from(playlist);
      playlistWithSongs['songIds'] = songIdList;
      playlistsWithSongs.add(playlistWithSongs);
    }

    return playlistsWithSongs;
  }

  Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
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

  Future<void> updatePlaylist(Playlist playlist) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'playlists',
        {'name': playlist.name},
        where: 'id = ?',
        whereArgs: [playlist.id],
      );

      await txn.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [playlist.id]);

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
          'position': position,
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

    final songDetailsById = {for (var map in songDetailMaps) map['id'] as String: Song.fromMap(map)};

    List<Song> songs = [];
    for (String songId in songIds) {
      if (songDetailsById.containsKey(songId)) {
        songs.add(songDetailsById[songId]!);
      }
    }
    return songs;
  }

  Future<void> cleanupPlaylistSongs() async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM playlist_songs
      WHERE songId NOT IN (SELECT id FROM songs)
    ''');
    await db.rawDelete('''
      DELETE FROM playlist_songs
      WHERE playlistId NOT IN (SELECT id FROM playlists)
    ''');
  }

  Future<List<Song>> deleteDuplicateSongs() async {
    final db = await database;
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

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final id in idsToDelete) {
        batch.delete('songs', where: 'id = ?', whereArgs: [id]);
      }
      await batch.commit(noResult: true);
    });

    _clearCache();
    return deletedSongs;
  }

  // 用户设置相关方法
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'user_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    
    if (result.isNotEmpty) {
      return result.first['value'] as String;
    }
    return null;
  }

  Future<void> deleteSetting(String key) async {
    final db = await database;
    await db.delete('user_settings', where: 'key = ?', whereArgs: [key]);
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query('user_settings');
    
    Map<String, String> settings = {};
    for (var row in result) {
      settings[row['key']] = row['value'];
    }
    return settings;
  }
}
