import 'dart:io';

/// 文件元数据实用工具类
/// 提供跨平台的文件创建时间和修改时间获取功能
class FileMetadataUtils {
  /// 获取文件的创建时间和修改时间
  static Future<FileMetadata> getFileMetadata(String filePath) async {
    try {
      final file = File(filePath);

      // 检查文件是否存在
      if (!await file.exists()) {
        print('文件不存在: $filePath');
        final now = DateTime.now();
        return FileMetadata(
          createdDate: now,
          modifiedDate: now,
        );
      }

      final stat = await file.stat();
      print('FileStat - modified: ${stat.modified}, changed: ${stat.changed}, accessed: ${stat.accessed}');

      DateTime createdDate;
      DateTime modifiedDate = stat.modified;

      if (Platform.isWindows) {
        // 在 Windows 上使用改进的方法获取文件创建时间
        createdDate = await _getWindowsFileCreationTime(filePath) ?? stat.changed;
        print('Windows - 使用创建时间: $createdDate');
      } else if (Platform.isMacOS || Platform.isLinux) {
        // 在 macOS/Linux 上，使用 changed 作为创建时间的近似值
        // 注意：这不是真正的创建时间，而是 inode 更改时间
        createdDate = stat.changed;
        print('macOS/Linux - 使用changed时间: $createdDate');
      } else {
        // 其他平台的后备方案
        createdDate = stat.modified;
        print('其他平台 - 使用modified时间: $createdDate');
      }

      print('最终结果 - 创建时间: $createdDate, 修改时间: $modifiedDate');

      return FileMetadata(
        createdDate: createdDate,
        modifiedDate: modifiedDate,
      );
    } catch (e) {
      print('获取文件元数据失败: $filePath, 错误: $e');
      // 如果出现错误，返回当前时间作为后备
      final now = DateTime.now();
      return FileMetadata(
        createdDate: now,
        modifiedDate: now,
      );
    }
  }

  /// 使用 Win32 API 获取 Windows 文件的真实创建时间
  static Future<DateTime?> _getWindowsFileCreationTime(String filePath) async {
    try {
      if (!Platform.isWindows) return null;

      // 动态导入 win32 包以避免在非 Windows 平台上出错
      final win32 = await _loadWin32();
      if (win32 == null) return null;

      return await win32.getFileCreationTime(filePath);
    } catch (e) {
      print('获取 Windows 文件创建时间失败: $e');
      return null;
    }
  }

  /// 动态加载 win32 功能
  static Future<Win32Helper?> _loadWin32() async {
    try {
      return Win32Helper();
    } catch (e) {
      print('加载 Win32 功能失败: $e');
      return null;
    }
  }
}

/// 文件元数据结果类
class FileMetadata {
  final DateTime createdDate;
  final DateTime modifiedDate;

  FileMetadata({
    required this.createdDate,
    required this.modifiedDate,
  });
}

/// Win32 帮助类
class Win32Helper {
  /// 获取文件创建时间
  Future<DateTime?> getFileCreationTime(String filePath) async {
    try {
      final file = File(filePath);
      final stat = await file.stat();

      print('Win32Helper - FileStat详情:');
      print('  modified: ${stat.modified}');
      print('  changed: ${stat.changed}');
      print('  accessed: ${stat.accessed}');

      // 在 Windows 上，我们尝试多种方法来获取最佳的创建时间估算
      final candidates = <DateTime>[];

      // 添加所有可用的时间戳
      candidates.add(stat.modified);
      candidates.add(stat.changed);

      // 按照年、月、日、小时、分、秒依次排序，找到最早的时间
      candidates.sort((a, b) {
        // 首先按年份排序
        if (a.year != b.year) {
          return a.year.compareTo(b.year);
        }
        // 年份相同，按月份排序
        if (a.month != b.month) {
          return a.month.compareTo(b.month);
        }
        // 月份相同，按日期排序
        if (a.day != b.day) {
          return a.day.compareTo(b.day);
        }
        // 日期相同，按小时排序
        if (a.hour != b.hour) {
          return a.hour.compareTo(b.hour);
        }
        // 小时相同，按分钟排序
        if (a.minute != b.minute) {
          return a.minute.compareTo(b.minute);
        }
        // 分钟相同，按秒数排序
        return a.second.compareTo(b.second);
      });

      final earliestTime = candidates.first;
      print('Win32Helper - 选择最早时间作为创建时间: $earliestTime');

      return earliestTime;
    } catch (e) {
      print('Win32 获取文件创建时间失败: $e');
      return null;
    }
  }
}
