import 'package:flutter/material.dart'; // 导入Flutter的Material组件库

class MusicWaveform extends StatefulWidget {
  // 音乐波形动画组件
  final Color color; // 波形颜色
  final double size; // 波形尺寸

  const MusicWaveform({
    super.key,
    this.color = Colors.white, // 默认颜色为白色
    this.size = 24, // 默认尺寸为24
  });

  @override
  State<MusicWaveform> createState() => _MusicWaveformState(); // 创建状态对象
}

class _MusicWaveformState extends State<MusicWaveform> with TickerProviderStateMixin {
  // 状态类，混入TickerProviderStateMixin用于动画
  late List<AnimationController> _controllers; // 动画控制器列表
  late List<Animation<double>> _animations; // 动画列表

  @override
  void initState() {
    // 初始化状态
    super.initState();

    _controllers = List.generate(
      4, // 生成4个动画控制器
      (index) => AnimationController(
        duration: Duration(milliseconds: 300 + (index * 100)), // 每个控制器持续时间不同
        vsync: this, // 绑定vsync
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut), // 使用缓动曲线
      );
    }).toList();

    for (int i = 0; i < _controllers.length; i++) {
      // 启动动画，依次延迟
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true); // 循环往返动画
        }
      });
    }
  }

  @override
  void dispose() {
    // 释放资源
    for (var controller in _controllers) {
      controller.dispose(); // 销毁控制器
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 构建界面
    return SizedBox(
      width: widget.size, // 组件宽度
      height: widget.size, // 组件高度
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 均匀分布
        crossAxisAlignment: CrossAxisAlignment.center, // 垂直居中
        children: List.generate(
          4, // 生成4个波形条
          (index) => AnimatedBuilder(
            animation: _animations[index], // 绑定动画
            builder: (context, child) {
              return Container(
                width: widget.size * 0.1, // 波形条宽度
                height: widget.size * _animations[index].value, // 波形条高度随动画变化
                decoration: BoxDecoration(
                  color: widget.color, // 波形颜色
                  borderRadius: BorderRadius.circular(widget.size * 0.05), // 圆角
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
