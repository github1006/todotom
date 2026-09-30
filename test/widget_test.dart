import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:todotom/core/app_dependencies.dart';
import 'package:todotom/database/app_database.dart';
import 'package:todotom/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    AppDependencies.resetForTesting();
    await AppDependencies.initializeWithDatabase(
      AppDatabase(
        databaseFactory: databaseFactoryFfi,
        dbPath: ':memory:widget_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
  });

  testWidgets('Muestra pantalla vacía al iniciar', (WidgetTester tester) async {
    final dependencies = AppDependencies.instance;

    await tester.runAsync(() async {
      await tester.pumpWidget(TodoTomApp(dependencies: dependencies));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump();

    expect(find.text('Sin tareas'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });
}
