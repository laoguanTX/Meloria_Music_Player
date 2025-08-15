import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../providers/music_provider.dart';
import '../services/audio_player_adapter.dart' as adapter;
import 'package:shared_preferences/shared_preferences.dart';

class EqualizerScreen extends StatefulWidget {
  const EqualizerScreen({super.key});

  @override
  State<EqualizerScreen> createState() => _EqualizerScreenState();
}

class _EqualizerScreenState extends State<EqualizerScreen> {
  static const List<String> _bandLabels = ['32', '64', '125', '250', '500', '1k', '2k', '4k', '8k', '16k'];
  static const double minGain = -15.0;
  static const double maxGain = 15.0;

  late adapter.AudioPlayer _player;
  bool _enabled = false;
  final List<double> _gains = List.filled(10, 0.0);
  String _currentPreset = '自定义';
  final Map<String, List<double>> _presets = {
    '重低音': [8, 6, 4, 2, 0, -1, -2, -3, -4, -5],
    '流行': [0, 2, 4, 5, 3, 0, -1, -1, 0, 0],
    '摇滚': [5, 4, 3, 1, 0, 2, 4, 5, 5, 4],
    '电子': [4, 3, 2, 1, 0, 2, 4, 6, 6, 5],
    '人声': [-2, -1, 0, 2, 4, 5, 4, 2, 0, -1],
    '古典': [0, 0, 1, 3, 5, 5, 3, 1, 0, 0],
    '爵士': [2, 3, 4, 3, 1, 0, 1, 2, 3, 4],
    '舞曲': [6, 5, 4, 2, 0, 1, 3, 5, 6, 6],
  };

  @override
  void initState() {
    super.initState();
    final musicProvider = Provider.of<MusicProvider>(context, listen: false);
    _player = musicProvider.audioPlayerInstance;
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enabled = prefs.getBool('eq_enabled') ?? false;
      for (int i = 0; i < 10; i++) {
        _gains[i] = prefs.getDouble('eq_band_$i') ?? 0.0;
      }
    });
    await _applyAll();
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('eq_enabled', _enabled);
    for (int i = 0; i < 10; i++) {
      await prefs.setDouble('eq_band_$i', _gains[i]);
    }
  }

  Future<void> _applyAll() async {
    await _player.enableEqualizer(_enabled);
    if (_enabled) {
      for (int i = 0; i < 10; i++) {
        await _player.setEqGain(i, _gains[i]);
      }
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    setState(() => _enabled = value);
    await _player.enableEqualizer(value);
    if (value) {
      for (int i = 0; i < 10; i++) {
        await _player.setEqGain(i, _gains[i]);
      }
    }
    _saveState();
  }

  Future<void> _reset() async {
    setState(() {
      for (int i = 0; i < 10; i++) {
        _gains[i] = 0.0;
      }
      _currentPreset = '自定义';
    });
    _player.resetEqualizer();
    await _applyAll();
    _saveState();
  }

  Future<void> _applyPreset(String name) async {
    final values = _presets[name];
    if (values == null) return;
    setState(() {
      for (int i = 0; i < 10; i++) {
        _gains[i] = values[i].toDouble();
      }
      _currentPreset = name;
      _enabled = true;
    });
    await _applyAll();
    _saveState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: DragToMoveArea(
          child: const Align(
            alignment: Alignment.center,
            child: Text('均衡器'),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '重置',
            onPressed: _reset,
            icon: const Icon(Icons.refresh),
          )
        ],
        actionsPadding: const EdgeInsets.only(right: 10),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.surfaceVariant.withOpacity(0.35), theme.colorScheme.surface.withOpacity(0.6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme),
              const SizedBox(height: 12),
              _buildPresetsWrap(theme),
              const SizedBox(height: 12),
              Expanded(child: _buildSlidersPanel(theme)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('当前预设: ', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 4),
                  Chip(
                    label: Text(_currentPreset),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Switch(
          value: _enabled,
          onChanged: (v) => _toggleEnabled(v),
        ),
        Text('启用均衡器', style: theme.textTheme.titleMedium),
        const SizedBox(width: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 400),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _enabled ? theme.colorScheme.primary.withOpacity(0.15) : theme.colorScheme.outlineVariant.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _enabled ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq, size: 18, color: _enabled ? theme.colorScheme.primary : theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(_enabled ? 'Active' : 'Inactive',
                  style: TextStyle(fontSize: 12, color: _enabled ? theme.colorScheme.primary : theme.colorScheme.outline)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildPresetsWrap(ThemeData theme) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presets.keys.map((p) {
            final selected = _currentPreset == p;
            return ChoiceChip(
              label: Text(p),
              selected: selected,
              onSelected: (_) => _applyPreset(p),
              selectedColor: theme.colorScheme.primaryContainer,
              labelStyle: TextStyle(
                color: selected ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSlidersPanel(ThemeData theme) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary.withOpacity(0.06), theme.colorScheme.secondary.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DbScale(theme: theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(10, (i) {
                      return Expanded(
                        child: _AnimatedEqSlider(
                          label: _bandLabels[i],
                          value: _gains[i],
                          enabled: _enabled,
                          onChanged: (v) async {
                            setState(() {
                              _gains[i] = v;
                              _currentPreset = '自定义';
                            });
                            if (_enabled) {
                              await _player.setEqGain(i, v);
                            }
                          },
                          onChangeEnd: (_) => _saveState(),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AnimatedEqSlider extends StatelessWidget {
  final String label;
  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  const _AnimatedEqSlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.onChangeEnd,
  });

  Color _colorForGain(ThemeData theme, double gain) {
    if (!enabled) return theme.disabledColor;
    if (gain > 6) return theme.colorScheme.primary;
    if (gain > 0) return theme.colorScheme.primary.withOpacity(0.8);
    if (gain < -6) return theme.colorScheme.errorContainer;
    if (gain < 0) return theme.colorScheme.tertiary.withOpacity(0.7);
    return theme.colorScheme.outline;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value.clamp(_EqualizerScreenState.minGain, _EqualizerScreenState.maxGain);
    final color = _colorForGain(theme, display.toDouble());
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Tooltip(
            message: '$label Hz  ${display.toStringAsFixed(1)} dB',
            child: RotatedBox(
              quarterTurns: -1,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withOpacity(0.15),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
                  valueIndicatorColor: color,
                  showValueIndicator: ShowValueIndicator.always,
                ),
                child: Slider(
                  min: _EqualizerScreenState.minGain,
                  max: _EqualizerScreenState.maxGain,
                  divisions: 30,
                  label: '${display.toStringAsFixed(1)} dB',
                  value: display.toDouble(),
                  onChanged: enabled ? onChanged : null,
                  onChangeEnd: enabled ? onChangeEnd : null,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        Text('${display.toStringAsFixed(1)} dB', style: TextStyle(fontSize: 10, color: theme.textTheme.bodySmall?.color?.withOpacity(0.8))),
      ],
    );
  }
}

class _DbScale extends StatelessWidget {
  final ThemeData theme;
  const _DbScale({required this.theme});

  @override
  Widget build(BuildContext context) {
    final marks = [15, 12, 9, 6, 3, 0, -3, -6, -9, -12, -15];
    return SizedBox(
      width: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: marks
            .map((m) => Text(
                  '$m',
                  style: TextStyle(
                    fontSize: 11,
                    color: m == 0 ? theme.colorScheme.primary : theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                    fontWeight: m == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ))
            .toList(),
      ),
    );
  }
}
