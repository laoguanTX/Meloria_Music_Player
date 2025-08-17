import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/bass_ffi_service.dart';
import 'dart:convert';
import 'dart:math' as math;

// 频率响应曲线绘制器
class FrequencyResponsePainter extends CustomPainter {
  final List<double> controlPoints;
  final List<String> frequencyLabels;
  final bool isEnabled;
  final Color primaryColor;
  final Color backgroundColor;
  final Color gridColor;

  FrequencyResponsePainter({
    required this.controlPoints,
    required this.frequencyLabels,
    required this.isEnabled,
    required this.primaryColor,
    required this.backgroundColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = gridColor.withOpacity(0.3)
      ..strokeWidth = 1.0;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    // 绘制网格
    _drawGrid(canvas, size, gridPaint, textPainter);

    // 绘制频率响应曲线
    if (isEnabled) {
      _drawFrequencyResponse(canvas, size, paint);
    }

    // 绘制控制点
    _drawControlPoints(canvas, size, paint);
  }

  void _drawGrid(Canvas canvas, Size size, Paint gridPaint, TextPainter textPainter) {
    // 绘制水平网格线 (增益值)
    for (int i = -15; i <= 3; i += 3) {
      final y = size.height * (1 - (i + 15) / 18);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

      // 绘制增益标签
      textPainter.text = TextSpan(
        text: '${i}dB',
        style: TextStyle(color: gridColor, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // 绘制垂直网格线 (频率)
    for (int i = 0; i < frequencyLabels.length; i++) {
      final x = size.width * i / (frequencyLabels.length - 1);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);

      // 绘制频率标签
      textPainter.text = TextSpan(
        text: frequencyLabels[i],
        style: TextStyle(color: gridColor, fontSize: 9),
      );
      textPainter.layout();

      // 旋转文本
      canvas.save();
      canvas.translate(x + textPainter.height / 2, size.height - 5);
      canvas.rotate(-math.pi / 2);
      textPainter.paint(canvas, Offset(0, -textPainter.width));
      canvas.restore();
    }
  }

  void _drawFrequencyResponse(Canvas canvas, Size size, Paint paint) {
    paint.color = isEnabled ? primaryColor : primaryColor.withOpacity(0.3);

    // 使用三次样条插值生成平滑曲线
    final path = Path();
    final points = <Offset>[];

    // 生成更多点来创建平滑曲线
    for (int i = 0; i <= 100; i++) {
      final t = i / 100.0;
      final x = size.width * t;

      // 使用线性插值作为简化的样条插值
      final gain = _interpolateGain(t);
      final y = size.height * (1 - (gain + 15) / 18);

      points.add(Offset(x, y.clamp(0.0, size.height)));
    }

    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _drawControlPoints(Canvas canvas, Size size, Paint paint) {
    final pointPaint = Paint()
      ..color = isEnabled ? primaryColor : primaryColor.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < controlPoints.length; i++) {
      final x = size.width * i / (controlPoints.length - 1);
      final y = size.height * (1 - (controlPoints[i] + 15) / 18);

      // 绘制控制点
      canvas.drawCircle(Offset(x, y), 4, pointPaint);

      // 绘制控制点边框
      final borderPaint = Paint()
        ..color = backgroundColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(x, y), 4, borderPaint);
    }
  }

  double _interpolateGain(double t) {
    final index = t * (controlPoints.length - 1);
    final i = index.floor();
    final f = index - i;

    if (i >= controlPoints.length - 1) return controlPoints.last;
    if (i < 0) return controlPoints.first;

    // 线性插值
    return controlPoints[i] * (1 - f) + controlPoints[i + 1] * f;
  }

  @override
  bool shouldRepaint(FrequencyResponsePainter oldDelegate) {
    return controlPoints != oldDelegate.controlPoints || isEnabled != oldDelegate.isEnabled || primaryColor != oldDelegate.primaryColor;
  }
}

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  final BassFfiService _bassService = BassFfiService.instance;
  bool _isEqualizerEnabled = false;
  List<double> _controlPoints = List.filled(10, 0.0); // 10个控制点，初始值为0
  bool _isLoading = true;

  // 频率标签
  final List<String> _frequencyLabels = ['32Hz', '64Hz', '125Hz', '250Hz', '500Hz', '1kHz', '2kHz', '4kHz', '8kHz', '16kHz'];

  // 预设效果
  final Map<String, List<double>> _presets = {
    '关闭': List.filled(10, 0.0),
    '低音增强': [1.0, 0.5, -0.5, -2.0, -2.0, -2.0, -2.0, -2.0, -2.0, -2.0],
    '人声增强': [-2.0, -2.0, -2.0, -0.5, 0.5, 0.0, -0.5, -2.0, -2.0, -2.0],
    '高音增强': [-2.0, -2.0, -2.0, -2.0, -2.0, -2.0, -0.5, 0.5, 1.0, 1.0],
    'V型': [0.5, -0.5, -2.0, -3.5, -4.5, -4.5, -3.5, -2.0, -0.5, 0.5],
    '古典': [-2.0, -2.0, -2.0, -2.0, -2.0, -2.0, -3.5, -4.0, -4.5, -5.0],
    '流行': [-0.5, -1.0, -2.0, -2.0, -2.5, -2.5, -2.0, -1.0, -0.5, -0.5],
    '摇滚': [0.0, -0.5, -1.0, -2.0, -3.0, -3.0, -2.0, -1.0, -0.5, 0.0],
    '爵士': [-1.0, -2.0, -2.0, -1.0, -0.5, -0.5, -1.0, -2.0, -2.0, -1.0],
    '电子': [0.5, -0.5, -2.0, -2.0, -3.5, -1.5, -1.5, -0.5, 0.0, 0.5],
  };

  @override
  void initState() {
    super.initState();
    _loadEqualizerSettings();
  }

  // 加载均衡器设置
  Future<void> _loadEqualizerSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载启用状态
      _isEqualizerEnabled = prefs.getBool('spline_equalizer_enabled') ?? false;

      // 加载控制点设置
      final controlPointsJson = prefs.getString('spline_control_points');
      if (controlPointsJson != null) {
        final controlPointsList = List<double>.from(json.decode(controlPointsJson));
        if (controlPointsList.length == 10) {
          _controlPoints = controlPointsList;
        }
      }

      // 同步到 BASS 服务
      _bassService.enableSplineEqualizer(_isEqualizerEnabled);
      if (_isEqualizerEnabled) {
        for (int i = 0; i < _controlPoints.length; i++) {
          _bassService.setSplineControlPoint(i, _controlPoints[i]);
        }
        _bassService.applySplineCurve();
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
      await prefs.setBool('spline_equalizer_enabled', _isEqualizerEnabled);
      await prefs.setString('spline_control_points', json.encode(_controlPoints));
    } catch (e) {
      print('保存均衡器设置失败: $e');
    }
  }

  // 切换均衡器启用状态
  void _toggleEqualizer(bool enabled) {
    setState(() {
      _isEqualizerEnabled = enabled;
    });

    _bassService.enableSplineEqualizer(enabled);
    if (enabled) {
      // 重新应用当前设置
      for (int i = 0; i < _controlPoints.length; i++) {
        _bassService.setSplineControlPoint(i, _controlPoints[i]);
      }
      _bassService.applySplineCurve();
    }

    _saveEqualizerSettings();
  }

  // 设置控制点增益
  void _setControlPoint(int index, double gain) {
    setState(() {
      _controlPoints[index] = gain;
    });

    if (_isEqualizerEnabled) {
      _bassService.setSplineControlPoint(index, gain);
      _bassService.applySplineCurve();
    }

    _saveEqualizerSettings();
  }

  // 应用预设
  void _applyPreset(String presetName) {
    if (_presets.containsKey(presetName)) {
      setState(() {
        _controlPoints = List.from(_presets[presetName]!);
      });

      if (_isEqualizerEnabled) {
        for (int i = 0; i < _controlPoints.length; i++) {
          _bassService.setSplineControlPoint(i, _controlPoints[i]);
        }
        _bassService.applySplineCurve();
      }

      _saveEqualizerSettings();

      // 显示提示
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已应用预设: $presetName'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // 重置均衡器
  void _resetEqualizer() {
    setState(() {
      _controlPoints = List.filled(10, 0.0);
    });

    if (_isEqualizerEnabled) {
      _bassService.resetSplineEqualizer();
      _bassService.applySplineCurve();
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
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('音效均衡器'),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('音效均衡器'),
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        actions: [
          IconButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => _buildPresetsDialog(context),
              );
            },
            icon: const Icon(Icons.tune),
            tooltip: '预设效果',
          ),
          IconButton(
            onPressed: _resetEqualizer,
            icon: const Icon(Icons.refresh),
            tooltip: '重置',
          ),
        ],
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

              const SizedBox(height: 20),

              // 频率响应图表
              _buildFrequencyResponseChart(theme, isDark),

              const SizedBox(height: 20),

              // 均衡器控制面板
              _buildEqualizerControls(theme),

              const SizedBox(height: 20),

              // 预设快速选择
              _buildQuickPresets(theme),
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
        child: SwitchListTile(
          title: Text(
            '样条曲线均衡器',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: const Text('使用三次样条插值算法，提供专业级的31段平滑频率调节'),
          value: _isEqualizerEnabled,
          onChanged: _toggleEqualizer,
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isEqualizerEnabled ? theme.colorScheme.primary : theme.colorScheme.outline,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isEqualizerEnabled ? Icons.equalizer : Icons.equalizer_outlined,
              color: _isEqualizerEnabled ? theme.colorScheme.onPrimary : theme.colorScheme.surface,
            ),
          ),
        ),
      ),
    );
  }

  // 频率响应图表
  Widget _buildFrequencyResponseChart(ThemeData theme, bool isDark) {
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
                Icon(
                  Icons.show_chart,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '频率响应曲线',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (_isEqualizerEnabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '已启用',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.3) : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.5),
                ),
              ),
              child: CustomPaint(
                size: const Size(double.infinity, 200),
                painter: FrequencyResponsePainter(
                  controlPoints: _controlPoints,
                  frequencyLabels: _frequencyLabels,
                  isEnabled: _isEqualizerEnabled,
                  primaryColor: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surface,
                  gridColor: theme.colorScheme.outline,
                ),
              ),
            ),
          ],
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
                Icon(
                  Icons.tune,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '频段控制',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 增益范围标签
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('+3dB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    )),
                Text('0dB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
                Text('-15dB',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    )),
              ],
            ),

            const SizedBox(height: 16),

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
                          Container(
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
                                  max: 3.0,
                                  divisions: 360, // (3 - (-15)) / 0.05 = 18 / 0.05 = 360
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

  // 预设快速选择
  Widget _buildQuickPresets(ThemeData theme) {
    final quickPresets = ['关闭', '低音增强', '人声增强', '高音增强', 'V型', '流行'];

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
                Icon(
                  Icons.library_music,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '快速预设',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickPresets.map((preset) {
                return ActionChip(
                  label: Text(preset),
                  onPressed: () => _applyPreset(preset),
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  side: BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _buildPresetsDialog(context),
                  );
                },
                icon: const Icon(Icons.more_horiz),
                label: const Text('查看所有预设'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 预设选择对话框
  Widget _buildPresetsDialog(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            Row(
              children: [
                Icon(
                  Icons.library_music,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  '选择预设效果',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 预设列表
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _presets.length,
                itemBuilder: (context, index) {
                  final presetName = _presets.keys.elementAt(index);
                  final presetValues = _presets[presetName]!;

                  // 计算预设的特征描述
                  String description = _getPresetDescription(presetValues);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).pop();
                        _applyPreset(presetName);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // 预设图标
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getPresetIcon(presetName),
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),

                            const SizedBox(width: 12),

                            // 预设信息
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    presetName,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 箭头图标
                            Icon(
                              Icons.chevron_right,
                              color: theme.colorScheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // 关闭按钮
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('取消'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 获取预设描述
  String _getPresetDescription(List<double> values) {
    if (values.every((v) => v == 0.0)) return '所有频段均为 0dB';

    final bassGain = (values[0] + values[1]) / 2;
    final midGain = (values[3] + values[4] + values[5] + values[6]) / 4;
    final trebleGain = (values[8] + values[9]) / 2;

    List<String> parts = [];
    if (bassGain > 1.0) parts.add('低音增强');
    if (bassGain < -1.0) parts.add('低音衰减');
    if (midGain > 1.0) parts.add('中音增强');
    if (midGain < -1.0) parts.add('中音衰减');
    if (trebleGain > 1.0) parts.add('高音增强');
    if (trebleGain < -1.0) parts.add('高音衰减');

    return parts.isEmpty ? '自定义调节' : parts.join('，');
  }

  // 获取预设图标
  IconData _getPresetIcon(String presetName) {
    switch (presetName) {
      case '关闭':
        return Icons.equalizer_outlined;
      case '低音增强':
        return Icons.vibration;
      case '人声增强':
        return Icons.record_voice_over;
      case '高音增强':
        return Icons.graphic_eq;
      case 'V型':
        return Icons.trending_down;
      case '古典':
        return Icons.piano;
      case '流行':
        return Icons.music_note;
      case '摇滚':
        return Icons.electric_bolt;
      case '爵士':
        return Icons.music_video;
      case '电子':
        return Icons.audiotrack;
      default:
        return Icons.tune;
    }
  }
}
