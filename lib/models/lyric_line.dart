class LyricLine {
  final Duration timestamp;
  final String text;

  LyricLine(this.timestamp, this.text);

  @override
  String toString() {
    return 'LyricLine{timestamp: $timestamp, text: "$text"}';
  }
}
