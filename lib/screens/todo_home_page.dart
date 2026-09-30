import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/app_dependencies.dart';
import '../models/place.dart';
import '../models/reminder_sound.dart';
import '../models/todo_item.dart';
import '../services/notification_service.dart';
import '../services/system_reminder_sound_service.dart';
import '../utils/todo_txt_parser.dart';
import '../widgets/todo_editor_dialog.dart';
import 'places_page.dart';

class TodoHomePage extends StatefulWidget {
  const TodoHomePage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<TodoHomePage> createState() => _TodoHomePageState();
}

class _TodoHomePageState extends State<TodoHomePage> with WidgetsBindingObserver {
  final List<TodoItem> _todos = [];
  final List<Place> _places = [];
  bool _loading = true;
  bool _remindersEnabled = true;
  ReminderSoundConfig _reminderSound = const ReminderSoundConfig();

  bool get _hasLocationTodos =>
      _todos.any((todo) => !todo.done && todo.placeId != null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _hasLocationTodos) {
      _syncReminders(showFeedback: true);
    }
  }

  Future<void> _loadData() async {
    final todos = await widget.dependencies.todoRepository.getAll();
    final places = await widget.dependencies.placeRepository.getAll();
    final remindersEnabled = await widget.dependencies.settingsRepository.areRemindersEnabled();
    final reminderSound = await widget.dependencies.settingsRepository.getReminderSound();

    if (!mounted) return;
    setState(() {
      _todos
        ..clear()
        ..addAll(todos);
      _places
        ..clear()
        ..addAll(places);
      _remindersEnabled = remindersEnabled;
      _reminderSound = reminderSound;
      _loading = false;
    });

    await NotificationService.init();
    await NotificationService.syncChannels(reminderSound);
    await _syncReminders();
  }

  Future<void> _syncReminders({bool showFeedback = false}) async {
    final result = await widget.dependencies.reminderService.sync(
      places: _places,
      todos: _todos,
      remindersEnabled: _remindersEnabled,
    );

    if (!mounted || !showFeedback) return;

    final message = result.isReady
        ? 'Recordatorio activo. Si ya estás en ese lugar, te avisará en unos segundos. Si no, al llegar.'
        : result.message;
    if (message.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: result.openSettings
            ? SnackBarAction(
                label: 'Ajustes',
                onPressed: openAppSettings,
              )
            : null,
      ),
    );
  }

  Future<void> _saveSettings() async {
    await widget.dependencies.settingsRepository.setRemindersEnabled(_remindersEnabled);
    await widget.dependencies.settingsRepository.setReminderSound(_reminderSound);
    await NotificationService.syncChannels(_reminderSound);
    await _syncReminders();
  }

  Future<ReminderSoundConfig?> _pickReminderSound() async {
    final picked = await SystemReminderSoundService.pickSound(
      existingUri: _reminderSound.uri,
    );
    if (picked == null || !mounted) return null;

    final sound = ReminderSoundConfig(uri: picked.uri, title: picked.title);
    setState(() => _reminderSound = sound);
    await widget.dependencies.settingsRepository.setReminderSound(sound);
    await NotificationService.syncChannels(sound);
    await _syncReminders();
    return sound;
  }

  Future<ReminderSoundConfig?> _useDefaultReminderSound() async {
    const sound = ReminderSoundConfig();
    setState(() => _reminderSound = sound);
    await widget.dependencies.settingsRepository.clearReminderSound();
    await NotificationService.syncChannels(sound);
    await _syncReminders();
    return sound;
  }

  Future<void> _savePlacesAndTodos() async {
    await widget.dependencies.placeRepository.replaceAll(_places);
    await widget.dependencies.todoRepository.replaceAll(_todos);
    await _syncReminders();
  }

  Place? _placeById(String? id) {
    if (id == null) return null;
    for (final place in _places) {
      if (place.id == id) return place;
    }
    return null;
  }

  Future<void> _openPlaces() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PlacesPage(
          places: _places,
          remindersEnabled: _remindersEnabled,
          reminderSound: _reminderSound,
          onPickReminderSound: _pickReminderSound,
          onUseDefaultReminderSound: _useDefaultReminderSound,
          onPlacesChanged: (places) async {
            final placeIds = places.map((p) => p.id).toSet();
            setState(() {
              _places
                ..clear()
                ..addAll(places);
              for (var i = 0; i < _todos.length; i++) {
                final placeId = _todos[i].placeId;
                if (placeId != null && !placeIds.contains(placeId)) {
                  _todos[i] = _todos[i].copyWith(clearPlace: true);
                }
              }
            });
            await _savePlacesAndTodos();
          },
          onRemindersEnabledChanged: (enabled) async {
            setState(() => _remindersEnabled = enabled);
            await _saveSettings();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<TodoItem?> _showTodoDialog({TodoItem? todo}) {
    return showDialog<TodoItem>(
      context: context,
      builder: (context) => TodoEditorDialog(places: _places, todo: todo),
    );
  }

  Future<void> _addTodo() async {
    final todo = await _showTodoDialog();
    if (todo == null) return;

    setState(() => _todos.insert(0, todo));
    await widget.dependencies.todoRepository.upsert(todo);
    await _syncReminders(showFeedback: todo.placeId != null);
  }

  Future<void> _editTodo(int index) async {
    final updated = await _showTodoDialog(todo: _todos[index]);
    if (updated == null) return;

    setState(() => _todos[index] = updated);
    await widget.dependencies.todoRepository.upsert(updated);
    await _syncReminders(showFeedback: updated.placeId != null);
  }

  Future<void> _toggleTodo(int index) async {
    setState(() => _todos[index].done = !_todos[index].done);
    await widget.dependencies.todoRepository.upsert(_todos[index]);
    await _syncReminders();
  }

  Future<void> _deleteTodo(int index) async {
    final todo = _todos[index];
    setState(() => _todos.removeAt(index));
    await widget.dependencies.todoRepository.delete(todo.id);
    await _syncReminders();
  }

  Future<void> _clearCompleted() async {
    setState(() => _todos.removeWhere((t) => t.done));
    await widget.dependencies.todoRepository.deleteCompleted();
    await _syncReminders();
  }

  Future<void> _importFromTxt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    if (file.bytes == null) {
      _showMessage('No se pudo leer el archivo');
      return;
    }

    final content = utf8.decode(file.bytes!);
    final titles = parseTodoLines(content);
    if (titles.isEmpty) {
      _showMessage('El archivo no tiene tareas');
      return;
    }

    final existing = _todos.map((t) => t.title.toLowerCase()).toSet();
    final newTitles = titles.where((t) => !existing.contains(t.toLowerCase())).toList();
    final skipped = titles.length - newTitles.length;

    if (newTitles.isEmpty) {
      _showMessage('Todas las tareas del archivo ya existen');
      return;
    }

    final baseId = DateTime.now().microsecondsSinceEpoch;
    final newTodos = newTitles
        .asMap()
        .entries
        .map((e) => TodoItem(id: '${baseId}_${e.key}', title: e.value))
        .toList();

    setState(() => _todos.insertAll(0, newTodos));
    await widget.dependencies.todoRepository.upsertAll(newTodos);
    await _syncReminders();

    final imported = newTitles.length;
    final suffix = skipped > 0 ? ' ($skipped duplicada${skipped == 1 ? '' : 's'} omitida${skipped == 1 ? '' : 's'})' : '';
    _showMessage('Importadas $imported tarea${imported == 1 ? '' : 's'}$suffix');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  int get _pendingCount => _todos.where((t) => !t.done).length;

  @override
  Widget build(BuildContext context) {
    final hasCompleted = _todos.any((t) => t.done);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tareas'),
        actions: [
          IconButton(
            onPressed: _openPlaces,
            tooltip: 'Lugares en el mapa',
            icon: const Icon(Icons.place_outlined),
          ),
          IconButton(
            onPressed: _importFromTxt,
            tooltip: 'Importar .txt',
            icon: const Icon(Icons.upload_file_outlined),
          ),
          if (hasCompleted)
            IconButton(
              onPressed: _clearCompleted,
              tooltip: 'Limpiar completadas',
              icon: const Icon(Icons.cleaning_services_outlined),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _todos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.checklist_rtl,
                          size: 72,
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text('Sin tareas', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Text(
                          'Pulsa + para agregar, 📍 para marcar lugares o ↑ para importar un .txt',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _pendingCount == 0
                            ? '¡Todas completadas!'
                            : '$_pendingCount pendiente${_pendingCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _todos.length,
                        itemBuilder: (context, index) {
                          final todo = _todos[index];
                          final place = _placeById(todo.placeId);

                          return Dismissible(
                            key: ValueKey(todo.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: Theme.of(context).colorScheme.error,
                              child: Icon(
                                Icons.delete_outline,
                                color: Theme.of(context).colorScheme.onError,
                              ),
                            ),
                            onDismissed: (_) => _deleteTodo(index),
                            child: ListTile(
                              leading: Checkbox(
                                value: todo.done,
                                onChanged: (_) => _toggleTodo(index),
                              ),
                              title: Text(
                                todo.title,
                                style: TextStyle(
                                  decoration: todo.done ? TextDecoration.lineThrough : null,
                                  color: todo.done
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              subtitle: place == null
                                  ? null
                                  : Row(
                                      children: [
                                        Icon(
                                          Icons.place,
                                          size: 14,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(child: Text('En ${place.name}')),
                                      ],
                                    ),
                              onTap: () => _toggleTodo(index),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined),
                                    onPressed: () => _editTodo(index),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => _deleteTodo(index),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTodo,
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarea'),
      ),
    );
  }
}
