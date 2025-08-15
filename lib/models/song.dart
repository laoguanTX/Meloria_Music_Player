import 'dart:typed_data';

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String filePath;
  final Duration duration;
  final Uint8List? albumArt;
  int playCount;
  final bool hasLyrics;
  String? embeddedLyrics;
  final DateTime? createdDate;
  final DateTime? modifiedDate;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.filePath,
    required this.duration,
    this.albumArt,
    this.playCount = 0,
    this.hasLyrics = false,
    this.embeddedLyrics,
    this.createdDate,
    this.modifiedDate,
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
      'playCount': playCount,
      'hasLyrics': hasLyrics ? 1 : 0,
      'embeddedLyrics': embeddedLyrics,
      'createdDate': createdDate?.millisecondsSinceEpoch,
      'modifiedDate': modifiedDate?.millisecondsSinceEpoch,
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
      playCount: map['playCount'] ?? 0,
      hasLyrics: map['hasLyrics'] == 1,
      embeddedLyrics: map['embeddedLyrics'],
      createdDate: map['createdDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['createdDate']) : null,
      modifiedDate: map['modifiedDate'] != null ? DateTime.fromMillisecondsSinceEpoch(map['modifiedDate']) : null,
    );
  }

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

class MusicFolder {
  final String id;
  final String name;
  final String path;
  final bool isAutoScan;
  final DateTime createdAt;
  final DateTime? lastScanTime;
  final int scanIntervalMinutes;
  final bool watchFileChanges;

  MusicFolder({
    required this.id,
    required this.name,
    required this.path,
    required this.isAutoScan,
    required this.createdAt,
    this.lastScanTime,
    this.scanIntervalMinutes = 30,
    this.watchFileChanges = true,
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
