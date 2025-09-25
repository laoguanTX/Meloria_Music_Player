class LyricLine {
  final Duration timestamp;
  final String text;
  final bool isPlaceholder;

  LyricLine(this.timestamp, this.text, {this.isPlaceholder = false});

  @override
  String toString() {
    return 'LyricLine{timestamp: $timestamp, text: "$text", isPlaceholder: $isPlaceholder}';
  }
}
