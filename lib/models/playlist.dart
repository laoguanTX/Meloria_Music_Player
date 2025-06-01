// lib/models/playlist.dart
import 'package:uuid/uuid.dart';

class Playlist {
  final String id;
  String name;
  List<String> songIds; // Added to store song IDs

  Playlist({String? id, required this.name, List<String>? songIds})
      : id = id ?? const Uuid().v4(),
        songIds = songIds ?? []; // Initialize with an empty list if not provided

  // toJson and fromJson methods for database persistence
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songIds': songIds,
      };

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        id: json['id'] as String,
        name: json['name'] as String,
        songIds: List<String>.from(json['songIds'] as List<dynamic>),
      );
}
