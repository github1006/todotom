import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/utils/todo_txt_parser.dart';

void main() {
  test('parseTodoLines lee guiones y líneas vacías', () {
    const content = '''
- Llamara a la Carla
- Comprar pernosn

Comprar leche
''';

    expect(parseTodoLines(content), [
      'Llamara a la Carla',
      'Comprar pernosn',
      'Comprar leche',
    ]);
  });

  test('parseTodoLines acepta otros formatos comunes', () {
    const content = '''
* Tarea con asterisco
1. Tarea numerada
2) Otra numerada
[ ] Pendiente markdown
[x] Hecha markdown
''';

    expect(parseTodoLines(content), [
      'Tarea con asterisco',
      'Tarea numerada',
      'Otra numerada',
      'Pendiente markdown',
      'Hecha markdown',
    ]);
  });
}
