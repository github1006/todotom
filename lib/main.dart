import 'package:flutter/material.dart';

import 'core/app_dependencies.dart';
import 'screens/todo_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dependencies = await AppDependencies.initialize();
  runApp(TodoTomApp(dependencies: dependencies));
}

class TodoTomApp extends StatelessWidget {
  const TodoTomApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TodoTom',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: TodoHomePage(dependencies: dependencies),
    );
  }
}
