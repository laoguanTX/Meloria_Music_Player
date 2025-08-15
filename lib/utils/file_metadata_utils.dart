import 'dart:io';

class FileMetadataUtils {
  static Future<FileMetadata> getFileMetadata(String filePath) async {
    final file = File(filePath);

    if (!await file.exists()) {
      final now = DateTime.now();
      return FileMetadata(
        createdDate: now,
        modifiedDate: now,
      );
    }

    final stat = await file.stat();
    DateTime createdDate;
    DateTime modifiedDate = stat.modified;

    createdDate = await _getWindowsFileCreationTime(filePath) ?? stat.changed;

    return FileMetadata(
      createdDate: createdDate,
      modifiedDate: modifiedDate,
    );
  }

  static Future<DateTime?> _getWindowsFileCreationTime(String filePath) async {
    if (!Platform.isWindows) return null;

    final win32 = await _loadWin32();
    if (win32 == null) return null;

    return await win32.getFileCreationTime(filePath);
  }

  static Future<Win32Helper?> _loadWin32() async {
    return Win32Helper();
  }
}

class FileMetadata {
  final DateTime createdDate;
  final DateTime modifiedDate;

  FileMetadata({
    required this.createdDate,
    required this.modifiedDate,
  });
}

class Win32Helper {
  Future<DateTime?> getFileCreationTime(String filePath) async {
    final file = File(filePath);
    final stat = await file.stat();
    final candidates = <DateTime>[];

    candidates.add(stat.modified);
    candidates.add(stat.changed);

    candidates.sort((a, b) {
      if (a.year != b.year) {
        return a.year.compareTo(b.year);
      }
      if (a.month != b.month) {
        return a.month.compareTo(b.month);
      }
      if (a.day != b.day) {
        return a.day.compareTo(b.day);
      }
      if (a.hour != b.hour) {
        return a.hour.compareTo(b.hour);
      }
      if (a.minute != b.minute) {
        return a.minute.compareTo(b.minute);
      }
      return a.second.compareTo(b.second);
    });
    final earliestTime = candidates.first;
    return earliestTime;
  }
}
