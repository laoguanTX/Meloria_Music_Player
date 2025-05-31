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
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton<String>(
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
                const PopupMenuDivider(),
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
}
