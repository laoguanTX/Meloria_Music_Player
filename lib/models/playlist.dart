import 'package:uuid/uuid.dart';

class Playlist {
  final String id;
  String name;
  List<String> songIds;

  Playlist({String? id, required this.name, List<String>? songIds})
      : id = id ?? const Uuid().v4(),
        songIds = songIds ?? [];

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
