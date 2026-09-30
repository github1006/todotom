import 'package:flutter/material.dart';

import '../core/app_dependencies.dart';
import 'todo_home_page.dart';
import 'travel/travel_hub_page.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _selectedIndex = 0;
  final _travelHubKey = GlobalKey<TravelHubPageState>();

  void _onTabSelected(int index) {
    setState(() => _selectedIndex = index);
    if (index == 1) {
      _travelHubKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TodoHomePage(dependencies: widget.dependencies),
          TravelHubPage(
            key: _travelHubKey,
            dependencies: widget.dependencies,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tareas',
          ),
          NavigationDestination(
            icon: Icon(Icons.luggage_outlined),
            selectedIcon: Icon(Icons.luggage),
            label: 'Maleta',
          ),
        ],
      ),
    );
  }
}
