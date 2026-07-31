String formatResumeText(String value) {
  final lines = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .split('\n')
      .map(_formatResumeLine)
      .toList();

  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }

  final result = <String>[];
  var previousWasEmpty = false;
  for (final line in lines) {
    if (line.isEmpty) {
      if (!previousWasEmpty) result.add('');
      previousWasEmpty = true;
    } else {
      result.add(line);
      previousWasEmpty = false;
    }
  }
  return result.join('\n');
}

String _formatResumeLine(String source) {
  var line = source.trim().replaceAll(RegExp(r'[ \t]+'), ' ');
  if (line.isEmpty) return '';

  line = line.replaceFirst(RegExp(r'^[-–—•*]\s*'), '— ');
  line = line.replaceAllMapped(
    RegExp(r'"([^"\n]+)"'),
    (match) => '«${match.group(1)!.trim()}»',
  );
  line = line.replaceAllMapped(
    RegExp(r'([.,;:!?])(?=[А-Яа-яЁёA-Za-z0-9])'),
    (match) => '${match.group(1)} ',
  );
  line = line
      .replaceAll(RegExp('съемка', caseSensitive: false), 'съёмка')
      .replaceAll(RegExp('съемки', caseSensitive: false), 'съёмки')
      .replaceAll(RegExp('съемке', caseSensitive: false), 'съёмке')
      .replaceAll(RegExp('съемок', caseSensitive: false), 'съёмок');
  return line;
}
