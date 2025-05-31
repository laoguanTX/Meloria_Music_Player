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
      version: 7, // Increment database version to 7
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
        FOREIGN KEY (playlistId) REFERENCES playlists (id),
        FOREIGN KEY (songId) REFERENCES songs (id),
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
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 重新创建 songs 表以支持 BLOB 类型的 albumArt
      await db.execute('DROP TABLE IF EXISTS songs');
      // When dropping and recreating, ensure the new table has all current columns
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
      // 添加文件夹表, 使用 IF NOT EXISTS 避免在表已存在时出错
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
      // Check if playCount column exists before trying to add it,
      // especially if version 2 path was taken which recreates the table.
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool playCountExists = tableInfo.any((column) => column['name'] == 'playCount');
      if (!playCountExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN playCount INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (oldVersion < 5) {
      // Add hasLyrics column if it doesn't exist
      // This check is important if the table was recreated in an earlier upgrade step (e.g., oldVersion < 2)
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool hasLyricsExists = tableInfo.any((column) => column['name'] == 'hasLyrics');
      if (!hasLyricsExists) {
        await db.execute('ALTER TABLE songs ADD COLUMN hasLyrics INTEGER NOT NULL DEFAULT 0');
      }
    }
    // Ensure embeddedLyrics column is added if upgrading from a version < 6
    if (oldVersion < 6) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool embeddedLyricsExists = tableInfo.any((column) => column['name'] == 'embeddedLyrics');
      if (!embeddedLyricsExists) {
        // print(
        //     'Upgrading database: Adding embeddedLyrics column (oldVersion < 6 path)');
        await db.execute('ALTER TABLE songs ADD COLUMN embeddedLyrics TEXT');
      }
    }
    // Add a specific check for version 7 to be absolutely sure,
    // in case the upgrade to version 6 had issues or was incomplete.
    if (oldVersion < 7) {
      var tableInfo = await db.rawQuery("PRAGMA table_info(songs)");
      bool embeddedLyricsExists = tableInfo.any((column) => column['name'] == 'embeddedLyrics');
      if (!embeddedLyricsExists) {
        // print(
        //     'Upgrading database: Adding embeddedLyrics column (oldVersion < 7 path)');
        await db.execute('ALTER TABLE songs ADD COLUMN embeddedLyrics TEXT');
      }
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
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM songs');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // 检查歌曲是否存在
  Future<bool> songExists(String id) async {
    final db = await database;
    final result = await db.query(
      'songs',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  // 文件夹管理方法
  Future<void> insertFolder(MusicFolder folder) async {
    final db = await database;
    await db.insert(
      'folders',
      folder.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MusicFolder>> getAllFolders() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('folders', orderBy: 'createdAt DESC');

    return List.generate(maps.length, (i) {
      return MusicFolder.fromMap(maps[i]);
    });
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

  Future<bool> folderExists(String path) async {
    final db = await database;
    final result = await db.query(
      'folders',
      where: 'path = ?',
      whereArgs: [path],
      limit: 1,
    );
    return result.isNotEmpty;
  }
}
