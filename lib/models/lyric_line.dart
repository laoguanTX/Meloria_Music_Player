class LyricLine {
  // 歌词行类
  final Duration timestamp; // 歌词出现的时间戳
  final String text; // 歌词文本
  final String? translatedText; // 可选：翻译后的歌词文本

  LyricLine(this.timestamp, this.text, {this.translatedText}); // 构造函数，支持可选的翻译歌词

  @override
  String toString() {
    // 重写toString方法，便于打印调试
    return 'LyricLine{timestamp: $timestamp, text: "$text", translatedText: "$translatedText"}'; // 返回包含所有字段的字符串
  }
}
