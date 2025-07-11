import 'dart:typed_data';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final Uint8List? albumArt; // 专辑图片数据
  int playCount; // 新增播放次数字段
  final bool hasLyrics; // 新增歌词判断字段
  String? embeddedLyrics; // 新增内嵌歌词字段
  final DateTime? createdDate; // 文件创建日期
  final DateTime? modifiedDate; // 文件修改日期

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    this.albumArt,
    this.playCount = 0, // 初始化播放次数为0
    this.hasLyrics = false, // 初始化歌词状态
    this.embeddedLyrics, // 初始化内嵌歌词
    this.createdDate, // 文件创建日期
    this.modifiedDate, // 文件修改日期
  });
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'album': album,
      'filePath': filePath,
      'duration': duration.inMilliseconds,
      'albumArt': albumArt,
      'playCount': playCount, // 添加到toMap
      'hasLyrics': hasLyrics ? 1 : 0, // 将布尔值转换为整数
      'embeddedLyrics': embeddedLyrics, // 添加到toMap
      'createdDate': createdDate?.millisecondsSinceEpoch, // 添加创建日期
      'modifiedDate': modifiedDate?.millisecondsSinceEpoch, // 添加修改日期
    };
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    return Song(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      album: map['album'],
      filePath: map['filePath'],
      duration: Duration(milliseconds: map['duration']),
      albumArt: map['albumArt'] is Uint8List ? map['albumArt'] : null,
      playCount: map['playCount'] ?? 0, // 从fromMap初始化
      hasLyrics: map['hasLyrics'] == 1, // 将整数转换为布尔值
      embeddedLyrics: map['embeddedLyrics'], // 从fromMap初始化
      createdDate: map['createdDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['createdDate']) : null, // 从fromMap初始化创建日期
      modifiedDate: map['modifiedDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['modifiedDate']) : null, // 从fromMap初始化修改日期
    );
  }

  // 新增：copyWith方法，用于创建Song的副本并修改特定字段
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? filePath,
    Duration? duration,
    Uint8List? albumArt,
    int? playCount,
    bool? hasLyrics,
    String? embeddedLyrics,
    DateTime? createdDate,
    DateTime? modifiedDate,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      filePath: filePath ?? this.filePath,
      duration: duration ?? this.duration,
      albumArt: albumArt ?? this.albumArt,
      playCount: playCount ?? this.playCount,
      hasLyrics: hasLyrics ?? this.hasLyrics,
      embeddedLyrics: embeddedLyrics ?? this.embeddedLyrics,
      createdDate: createdDate ?? this.createdDate,
      modifiedDate: modifiedDate ?? this.modifiedDate,
    );
  }
}

// class Playlist {
//   final String id;
//   final String name;
//   final List<Song> songs;
//   final DateTime createdAt;

//   Playlist({
//     required this.id,
//     required this.name,
//     required this.songs,
//     required this.createdAt,
//   });

//   Map<String, dynamic> toMap() {
//     return {
//       'id': id,
//       'name': name,
//       'songs': songs.map((song) => song.toMap()).toList(),
//       'createdAt': createdAt.toIso8601String(),
//     };
//   }

//   factory Playlist.fromMap(Map<String, dynamic> map) {
//     return Playlist(
//       id: map['id'],
//       name: map['name'],
//       songs: (map['songs'] as List).map((songMap) => Song.fromMap(songMap)).toList(),
//       createdAt: DateTime.parse(map['createdAt']),
//     );
//   }
// }

class MusicFolder {
  final String id;
  final String name;
  final String path;
  final bool isAutoScan;
  final DateTime createdAt;
  final DateTime? lastScanTime;
  final int scanIntervalMinutes; // 扫描间隔（分钟）
  final bool watchFileChanges; // 是否监控文件变化

  MusicFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.isAutoScan,
    required this.createdAt,
    this.lastScanTime,
    this.scanIntervalMinutes = 30, // 默认30分钟
    this.watchFileChanges = true, // 默认开启文件监控
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'isAutoScan': isAutoScan ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'lastScanTime': lastScanTime?.toIso8601String(),
      'scanIntervalMinutes': scanIntervalMinutes,
      'watchFileChanges': watchFileChanges ? 1 : 0,
    };
  }

  factory MusicFolder.fromMap(Map<String, dynamic> map) {
    return MusicFolder(
      id: map['id'],
      name: map['name'],
      path: map['path'],
      isAutoScan: map['isAutoScan'] == 1,
      createdAt: DateTime.parse(map['createdAt']),
      lastScanTime: map['lastScanTime'] != null ? DateTime.parse(map['lastScanTime']) : null,
      scanIntervalMinutes: map['scanIntervalMinutes'] ?? 30,
      watchFileChanges: map['watchFileChanges'] == 1,
    );
  }

  MusicFolder copyWith({
    String? id,
    String? name,
    String? path,
    bool? isAutoScan,
    DateTime? createdAt,
    DateTime? lastScanTime,
    int? scanIntervalMinutes,
    bool? watchFileChanges,
  }) {
    return MusicFolder(
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      isAutoScan: isAutoScan ?? this.isAutoScan,
      createdAt: createdAt ?? this.createdAt,
      lastScanTime: lastScanTime ?? this.lastScanTime,
      scanIntervalMinutes: scanIntervalMinutes ?? this.scanIntervalMinutes,
      watchFileChanges: watchFileChanges ?? this.watchFileChanges,
    );
  }
}
