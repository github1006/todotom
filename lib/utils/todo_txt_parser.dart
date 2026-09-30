/// Convierte líneas de un .txt en títulos de tarea.
/// Acepta: "- tarea", "* tarea", "1. tarea", "[ ] tarea" o texto plano.
List<String> parseTodoLines(String content) {
  return content
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map(_normalizeTodoLine)
      .where((line) => line.isNotEmpty)
      .toList();
}

String _normalizeTodoLine(String line) {
  var text = line;
  text = text.replaceFirst(RegExp(r'^[-*•]\s+'), '');
  text = text.replaceFirst(RegExp(r'^\d+[.)]\s+'), '');
  text = text.replaceFirst(RegExp(r'^\[[ xX]\]\s*'), '');
  return text.trim();
}
