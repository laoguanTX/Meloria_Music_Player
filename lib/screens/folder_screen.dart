import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/music_provider.dart';
import '../models/song.dart';

class FolderTab extends StatefulWidget {
  const FolderTab({super.key});

  @override
  State<FolderTab> createState() => _FolderTabState();
}

class _FolderTabState extends State<FolderTab> {
  bool _isScanning = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, musicProvider, child) {
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight), // Consistent height
            child: Container(
              padding: const EdgeInsets.only(top: 20.0, left: 20.0, right: 20.0),
              color: Colors.transparent, // Or your desired AppBar background color
              child: Builder(builder: (context) {
                return NavigationToolbar(
                  leading: null, // No leading widget
                  middle: Text(
                    '音乐文件夹',
                    style: Theme.of(context).appBarTheme.titleTextStyle ?? Theme.of(context).textTheme.titleLarge,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _isScanning ? null : () => _rescanAllFolders(musicProvider),
                        icon: _isScanning
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        tooltip: '重新扫描所有文件夹',
                      ),
                      // 智能扫描按钮
                      IconButton(
                        onPressed: _isScanning ? null : () => _smartScan(musicProvider),
                        icon: const Icon(Icons.auto_fix_high),
                        tooltip: '智能扫描（只扫描需要更新的文件夹）',
                      ),
                      ElevatedButton.icon(
                        onPressed: _isScanning ? null : () => _addFolder(musicProvider),
                        icon: const Icon(Icons.add),
                        label: const Text('添加'), // Shorter label for AppBar
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8), // Adjust padding if needed
                        ),
                      ),
                    ],
                  ),
                  centerMiddle: true, // Center the title
                );
              }),
            ),
          ),
          body: Column(
            children: [
              // 头部操作区域 - REMOVED
              // Container(
              //   padding: const EdgeInsets.all(16.0),
              //   child: Row(
              //     children: [
              //       Text(
              //         '音乐文件夹',
              //         style:
              //             Theme.of(context).textTheme.headlineSmall?.copyWith(
              //                   fontWeight: FontWeight.bold,
              //                 ),
              //       ),
              //       const Spacer(),
              //       // 重新扫描按钮
              //       IconButton(
              //         onPressed: _isScanning
              //             ? null
              //             : () => _rescanAllFolders(musicProvider),
              //         icon: _isScanning
              //             ? const SizedBox(
              //                 width: 20,
              //                 height: 20,
              //                 child: CircularProgressIndicator(strokeWidth: 2),
              //               )
              //             : const Icon(Icons.refresh),
              //         tooltip: '重新扫描所有文件夹',
              //       ),
              //       // 添加文件夹按钮
              //       ElevatedButton.icon(
              //         onPressed:
              //             _isScanning ? null : () => _addFolder(musicProvider),
              //         icon: const Icon(Icons.add),
              //         label: const Text('添加文件夹'),
              //       ),
              //     ],
              //   ),
              // ),
              // const Divider(height: 1), // Can be removed if AppBar provides enough separation
              // 扫描进度显示
              _buildScanProgress(musicProvider),
              // 文件夹列表
              Expanded(
                child: musicProvider.folders.isEmpty ? _buildEmptyState() : _buildFolderList(musicProvider),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无音乐文件夹',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '添加文件夹后，系统会自动扫描其中的音乐文件',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addFolder(context.read<MusicProvider>()),
            icon: const Icon(Icons.add),
            label: const Text('添加文件夹'),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderList(MusicProvider musicProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: musicProvider.folders.length,
      itemBuilder: (context, index) {
        final folder = musicProvider.folders[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: Icon(
              Icons.folder,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: Text(folder.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  folder.path,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      folder.isAutoScan ? Icons.sync : Icons.sync_disabled,
                      size: 16,
                      color: folder.isAutoScan ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      folder.isAutoScan ? '自动扫描已启用' : '自动扫描已禁用',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: folder.isAutoScan ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                          ),
                    ),
                    if (folder.isAutoScan) ...[
                      const SizedBox(width: 8),
                      Text(
                        '(${folder.scanIntervalMinutes}分钟)',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                      ),
                    ],
                  ],
                ),
                if (folder.lastScanTime != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '上次扫描: ${_formatDateTime(folder.lastScanTime!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton<String>(
              tooltip: '更多',
              onSelected: (value) => _handleFolderAction(value, folder, musicProvider),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'scan',
                  child: Row(
                    children: [
                      const Icon(Icons.search),
                      const SizedBox(width: 8),
                      const Text('立即扫描'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle_auto_scan',
                  child: Row(
                    children: [
                      Icon(folder.isAutoScan ? Icons.sync_disabled : Icons.sync),
                      const SizedBox(width: 8),
                      Text(folder.isAutoScan ? '禁用自动扫描' : '启用自动扫描'),
                    ],
                  ),
                ),
                if (folder.isAutoScan) ...[
                  PopupMenuItem(
                    value: 'set_interval',
                    child: Row(
                      children: [
                        const Icon(Icons.schedule),
                        const SizedBox(width: 8),
                        const Text('设置扫描间隔'),
                      ],
                    ),
                  ),
                ],
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Text(
                        '移除文件夹',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 添加扫描进度显示
  Widget _buildScanProgress(MusicProvider musicProvider) {
    if (!musicProvider.isAutoScanning && musicProvider.currentScanStatus.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      child: Column(
        children: [
          Row(
            children: [
              if (musicProvider.isAutoScanning) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  musicProvider.currentScanStatus,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (musicProvider.isAutoScanning && musicProvider.totalFilesToScan > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: musicProvider.scanProgress / musicProvider.totalFilesToScan,
            ),
            const SizedBox(height: 4),
            Text(
              '${musicProvider.scanProgress}/${musicProvider.totalFilesToScan} 个文件',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addFolder(MusicProvider musicProvider) async {
    setState(() {
      _isScanning = true;
    });

    try {
      await musicProvider.addMusicFolder();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件夹添加成功，正在扫描音乐文件...'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加文件夹失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _rescanAllFolders(MusicProvider musicProvider) async {
    setState(() {
      _isScanning = true;
    });

    try {
      await musicProvider.rescanAllFolders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('文件夹扫描完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('扫描失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _smartScan(MusicProvider musicProvider) async {
    setState(() {
      _isScanning = true;
    });

    try {
      await musicProvider.smartScan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('智能扫描完成'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('智能扫描失败: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _handleFolderAction(String action, MusicFolder folder, MusicProvider musicProvider) async {
    switch (action) {
      case 'scan':
        setState(() {
          _isScanning = true;
        });
        try {
          await musicProvider.scanFolderForMusic(folder);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${folder.name} 扫描完成'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('扫描失败: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isScanning = false;
            });
          }
        }
        break;
      case 'toggle_auto_scan':
        try {
          await musicProvider.toggleFolderAutoScan(folder.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(folder.isAutoScan ? '已禁用自动扫描' : '已启用自动扫描'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('操作失败: $e'),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
        break;
      case 'set_interval':
        await _showScanIntervalDialog(folder, musicProvider);
        break;
      case 'remove':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定要移除文件夹 "${folder.name}" 吗？\n\n这不会删除文件夹中的音乐文件，只是从音乐库中移除。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('删除'),
              ),
            ],
          ),
        );

        if (confirmed == true) {
          try {
            await musicProvider.removeMusicFolder(folder.id);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('文件夹已移除'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('删除失败: $e'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
              );
            }
          }
        }
        break;
    }
  }

  Future<void> _showScanIntervalDialog(MusicFolder folder, MusicProvider musicProvider) async {
    int selectedInterval = folder.scanIntervalMinutes;

    final result = await showDialog<int>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('设置扫描间隔'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('文件夹: ${folder.name}'),
                  const SizedBox(height: 16),
                  const Text('选择自动扫描间隔时间:'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [5, 10, 15, 30, 60, 120, 180].map((minutes) {
                      return ChoiceChip(
                        label: Text(minutes < 60 ? '$minutes分钟' : '${minutes ~/ 60}小时'),
                        selected: selectedInterval == minutes,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              selectedInterval = minutes;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: '自定义（分钟）',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            final minutes = int.tryParse(value);
                            if (minutes != null && minutes > 0) {
                              setState(() {
                                selectedInterval = minutes;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(selectedInterval),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && result != folder.scanIntervalMinutes) {
      try {
        await musicProvider.setFolderScanInterval(folder.id, result);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('扫描间隔已设置为 ${result < 60 ? '$result分钟' : '${result ~/ 60}小时'}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('设置失败: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
  }
}
