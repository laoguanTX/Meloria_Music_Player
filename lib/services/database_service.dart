import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/song.dart';
import 'dart:io';

class DatabaseService {
  static Database? _database;
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
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
      CREATE TABLE playlists(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE playlist_songs(
        playlistId TEXT,
        songId TEXT,
        position INTEGER,
        FOREIGN KEY (playlistId) REFERENCES playlists (id) ON DELETE CASCADE,
        FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE,
        PRIMARY KEY (playlistId, songId)
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

      List<Map<String, dynamic>> oldPlaylistSongs = [];
      try {
        oldPlaylistSongs = await db.query('playlist_songs');
      } catch (e) {
        // Table might not exist if it's a very old version or first creation path
      }

      await db.execute('DROP TABLE IF EXISTS playlist_songs');
      await db.execute('''
        CREATE TABLE playlist_songs(
          playlistId TEXT,
          songId TEXT,
          position INTEGER,
          FOREIGN KEY (playlistId) REFERENCES playlists (id) ON DELETE CASCADE,
          FOREIGN KEY (songId) REFERENCES songs (id) ON DELETE CASCADE,
          PRIMARY KEY (playlistId, songId)
        )
      ''');
      // Restore old playlist_songs data
      if (oldPlaylistSongs.isNotEmpty) {
        for (var row in oldPlaylistSongs) {
          try {
            await db.insert('playlist_songs', row);
          } catch (e) {
            // Handle or log error if restoration fails for a row
          }
        }
      }
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
  }

  Future<List<Song>> getAllSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('songs');

    return List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });
  }

  // New method to increment play count
  Future<void> incrementPlayCount(String songId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE songs SET playCount = playCount + 1 WHERE id = ?',
      [songId],
    );
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

  Future<void> insertPlaylist(Playlist playlist) async {
    final db = await database;

    await db.insert(
        'playlists',
        {
          'id': playlist.id,
          'name': playlist.name,
          'createdAt': playlist.createdAt.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Insert playlist songs
    for (int i = 0; i < playlist.songs.length; i++) {
      await db.insert(
          'playlist_songs',
          {
            'playlistId': playlist.id,
            'songId': playlist.songs[i].id,
            'position': i,
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Playlist>> getAllPlaylists() async {
    final db = await database;
    final List<Map<String, dynamic>> playlistMaps = await db.query('playlists');

    List<Playlist> playlists = [];
    for (var playlistMap in playlistMaps) {
      final songs = await _getPlaylistSongs(playlistMap['id']);
      playlists.add(
        Playlist(
          id: playlistMap['id'],
          name: playlistMap['name'],
          songs: songs,
          createdAt: DateTime.parse(playlistMap['createdAt']),
        ),
      );
    }

    return playlists;
  }

  Future<List<Song>> _getPlaylistSongs(String playlistId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT s.* FROM songs s
      INNER JOIN playlist_songs ps ON s.id = ps.songId
      WHERE ps.playlistId = ?
      ORDER BY ps.position
    ''',
      [playlistId],
    );

    return List.generate(maps.length, (i) {
      return Song.fromMap(maps[i]);
    });
  }

  Future<void> deletePlaylist(String id) async {
    final db = await database;
    await db.delete('playlists', where: 'id = ?', whereArgs: [id]);
    await db.delete('playlist_songs', where: 'playlistId = ?', whereArgs: [id]);
  }

  // 批量删除歌曲
  Future<void> deleteSongs(List<String> ids) async {
    final db = await database;
    final batch = db.batch();

    for (String id in ids) {
      batch.delete('songs', where: 'id = ?', whereArgs: [id]);
      // 同时从播放列表中移除这些歌曲
      batch.delete('playlist_songs', where: 'songId = ?', whereArgs: [id]);
    }

    await batch.commit();
  }

  // 清理无效的播放列表歌曲（引用不存在的歌曲）
  Future<void> cleanupPlaylistSongs() async {
    final db = await database;
    await db.execute('''
      DELETE FROM playlist_songs 
      WHERE songId NOT IN (SELECT id FROM songs)
    ''');
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

  // 获取播放列表总数
  Future<int> getPlaylistCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM playlists');
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
}
