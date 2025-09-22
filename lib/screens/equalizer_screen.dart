import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import '../services/bass_ffi_service.dart';
import 'dart:convert';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final BassFfiService _bassService = BassFfiService.instance;
  bool _isEqualizerEnabled = false;
  List<double> _controlPoints = List.filled(10, 0.0); // 10段EQ，初始值为0dB
  bool _isLoading = true;
  double _preampDb = 0.0; // 前级增益（dB）

  // 频率标签
  final List<String> _frequencyLabels = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];

  @override
  void initState() {
    super.initState();
    _loadEqualizerSettings();
  }

  // 加载均衡器设置
  Future<void> _loadEqualizerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 读取新键；若不存在则尝试从旧键迁移
      _isEqualizerEnabled = prefs.getBool('equalizer_enabled') ?? prefs.getBool('spline_equalizer_enabled') ?? false;

      // 加载EQ频段增益
      final eqJson = prefs.getString('eq_band_gains') ?? prefs.getString('spline_control_points');
      if (eqJson != null) {
        final list = List<double>.from(json.decode(eqJson));
        if (list.length == 10) {
          _controlPoints = list;
        }
      }

      // 加载前置放大（Preamp）
      _preampDb = prefs.getDouble('equalizer_preamp_db') ?? 0.0;

      // 同步到 BASS 服务：仅当状态不一致时才切换，避免重复叠加
      final bool serviceEnabled = _bassService.isEqualizerEnabled;
      if (serviceEnabled != _isEqualizerEnabled) {
        _bassService.enableEqualizer(_isEqualizerEnabled);
      }
      if (_isEqualizerEnabled) {
        // 设置前置放大
        _bassService.setPreampDb(_preampDb);
        for (int i = 0; i < _controlPoints.length; i++) {
          _bassService.setEqGain(i, _controlPoints[i]);
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('加载均衡器设置失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 保存均衡器设置
  Future<void> _saveEqualizerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('equalizer_enabled', _isEqualizerEnabled);
      await prefs.setString('eq_band_gains', json.encode(_controlPoints));
      await prefs.setDouble('equalizer_preamp_db', _preampDb);
    } catch (e) {
      print('保存均衡器设置失败: $e');
    }
  }

  // 弹出数值编辑对话框（可重用）
  Future<void> _showEditValueDialog({
    required String title,
    required double initialValue,
    required double min,
    required double max,
    required ValueChanged<double> onSaved,
  }) async {
    final controller = TextEditingController(text: initialValue.toStringAsFixed(2));
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text(title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,+]'))],
                  decoration: InputDecoration(
                    hintText: '输入值 (范围 $min 到 $max dB)',
                    errorText: errorText,
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v.replaceAll(',', '.').replaceAll('+', ''));
                    setState(() {
                      if (parsed == null) {
                        errorText = '请输入有效数字';
                      } else if (parsed < min || parsed > max) {
                        errorText = '超出范围 ($min 到 $max)';
                      } else {
                        errorText = null;
                      }
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () {
                  final raw = controller.text.trim().replaceAll(',', '.').replaceAll('+', '');
                  final parsed = double.tryParse(raw);
                  if (parsed == null) {
                    setState(() => errorText = '请输入有效数字');
                    return;
                  }
                  if (parsed < min || parsed > max) {
                    setState(() => errorText = '超出范围 ($min 到 $max)');
                    return;
                  }
                  onSaved(parsed);
                  Navigator.of(context).pop();
                },
                child: const Text('保存'),
              ),
            ],
          );
        });
      },
    );
  }

  // 切换均衡器启用状态
  void _toggleEqualizer(bool enabled) {
    setState(() {
      _isEqualizerEnabled = enabled;
    });

    // 仅在状态变化时调用启用/禁用
    final bool current = _bassService.isEqualizerEnabled;
    if (current != enabled) {
      _bassService.enableEqualizer(enabled);
    }
    if (enabled) {
      // 重新应用当前设置
      _bassService.setPreampDb(_preampDb);
      for (int i = 0; i < _controlPoints.length; i++) {
        _bassService.setEqGain(i, _controlPoints[i]);
      }
    }

    _saveEqualizerSettings();
  }

  // 设置控制点增益
  void _setControlPoint(int index, double gain) {
    setState(() {
      _controlPoints[index] = gain;
    });

    if (_isEqualizerEnabled) {
      _bassService.setEqGain(index, gain);
    }

    _saveEqualizerSettings();
  }

  // 重置均衡器
  void _resetEqualizer() {
    setState(() {
      _controlPoints = List.filled(10, 0.0);
      _preampDb = 0.0;
    });

    if (_isEqualizerEnabled) {
      _bassService.resetEqualizer();
      _bassService.setPreampDb(_preampDb);
    }

    _saveEqualizerSettings();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('均衡器已重置'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: GestureDetector(
            onPanStart: (details) async {
              await windowManager.startDragging();
            },
            child: AppBar(
              title: const Text('音效均衡器'),
              elevation: 0,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: GestureDetector(
          onPanStart: (details) async {
            await windowManager.startDragging();
          },
          child: AppBar(
            title: const Text('音效均衡器'),
            elevation: 0,
            backgroundColor: theme.colorScheme.surface,
            actions: [
              IconButton(
                onPressed: _resetEqualizer,
                icon: const Icon(Icons.refresh),
                tooltip: '重置',
              ),
              const SizedBox(width: 10), // 添加10宽度的空白
            ],
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.background,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 启用开关卡片
              _buildEnableCard(theme),

              // 均衡器控制面板
              _buildEqualizerControls(theme),
            ],
          ),
        ),
      ),
    );
  }

  // 启用开关卡片
  Widget _buildEnableCard(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary.withOpacity(0.1),
              theme.colorScheme.primary.withOpacity(0.05),
            ],
          ),
        ),
        child: ListTile(
          leading: Icon(
            Icons.equalizer,
            color: theme.colorScheme.primary,
            size: 30,
          ),
          title: Text(
            '均衡器开关',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: _isEqualizerEnabled,
                  onChanged: _toggleEqualizer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 均衡器控制面板
  Widget _buildEqualizerControls(ThemeData theme) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.volume_up, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 6),
                Text('前置放大 (Preamp)', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (!_isEqualizerEnabled) return;
                    _showEditValueDialog(
                      title: '编辑 前置放大 (dB)',
                      initialValue: _preampDb,
                      min: -12.0,
                      max: 12.0,
                      onSaved: (v) {
                        setState(() => _preampDb = v);
                        if (_isEqualizerEnabled) _bassService.setPreampDb(_preampDb);
                        _saveEqualizerSettings();
                      },
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_preampDb >= 0 ? '+' : ''}${_preampDb.toStringAsFixed(2)} dB',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: _isEqualizerEnabled ? theme.colorScheme.primary : theme.disabledColor,
                inactiveTrackColor: theme.colorScheme.outline.withOpacity(0.3),
                thumbColor: _isEqualizerEnabled ? theme.colorScheme.primary : theme.disabledColor,
                overlayColor: theme.colorScheme.primary.withOpacity(0.2),
                trackHeight: 4,
              ),
              child: Slider(
                value: _preampDb,
                min: -12.0,
                max: 12.0,
                divisions: 600, // 0.05dB 步进
                onChanged: _isEqualizerEnabled
                    ? (v) {
                        setState(() => _preampDb = v);
                        _bassService.setPreampDb(_preampDb);
                        _saveEqualizerSettings();
                      }
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            // 滑块组
            SizedBox(
              height: 300,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(10, (index) {
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        children: [
                          // 增益值显示
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (!_isEqualizerEnabled) return;
                              _showEditValueDialog(
                                title: '编辑 ${_frequencyLabels[index]} (dB)',
                                initialValue: _controlPoints[index],
                                min: -15.0,
                                max: 15.0,
                                onSaved: (v) {
                                  _setControlPoint(index, v);
                                },
                              );
                            },
                            child: Container(
                              height: 30,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: _isEqualizerEnabled ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.outline.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  '${_controlPoints[index] >= 0 ? '+' : ''}${_controlPoints[index].toStringAsFixed(2)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _isEqualizerEnabled ? theme.colorScheme.primary : theme.colorScheme.outline,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 垂直滑块
                          Expanded(
                            child: RotatedBox(
                              quarterTurns: 3,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: _isEqualizerEnabled ? theme.colorScheme.primary : theme.disabledColor,
                                  inactiveTrackColor: theme.colorScheme.outline.withOpacity(0.3),
                                  thumbColor: _isEqualizerEnabled ? theme.colorScheme.primary : theme.disabledColor,
                                  overlayColor: theme.colorScheme.primary.withOpacity(0.2),
                                  thumbShape: const RoundSliderThumbShape(
                                    enabledThumbRadius: 8,
                                  ),
                                  trackHeight: 4,
                                ),
                                child: Slider(
                                  value: _controlPoints[index],
                                  min: -15.0,
                                  max: 15.0,
                                  divisions: 600, // (15 - (-15)) / 0.05 = 30 / 0.05 = 600
                                  onChanged: _isEqualizerEnabled ? (value) => _setControlPoint(index, value) : null,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // 频率标签
                          Container(
                            height: 40,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                _frequencyLabels[index],
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
