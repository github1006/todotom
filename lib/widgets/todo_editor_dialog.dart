import 'package:flutter/material.dart';

import '../models/place.dart';
import '../models/todo_item.dart';

class TodoEditorDialog extends StatefulWidget {
  const TodoEditorDialog({
    super.key,
    required this.places,
    this.todo,
  });

  final List<Place> places;
  final TodoItem? todo;

  @override
  State<TodoEditorDialog> createState() => _TodoEditorDialogState();
}

class _TodoEditorDialogState extends State<TodoEditorDialog> {
  late final TextEditingController _controller;
  String? _selectedPlaceId;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.todo?.title ?? '');
    _selectedPlaceId = widget.todo?.placeId;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;

    Navigator.pop(
      context,
      TodoItem(
        id: widget.todo?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        done: widget.todo?.done ?? false,
        placeId: _selectedPlaceId,
        createdAt: widget.todo?.createdAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.todo == null ? 'Nueva tarea' : 'Editar tarea'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '¿Qué necesitas hacer?',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String?>(
            initialValue: _selectedPlaceId,
            decoration: const InputDecoration(
              labelText: 'Recordar en',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Sin lugar'),
              ),
              ...widget.places.map(
                (place) => DropdownMenuItem<String?>(
                  value: place.id,
                  child: Text(place.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _selectedPlaceId = value),
          ),
          if (widget.places.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Crea lugares en el mapa (icono 📍) para recordatorios.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          onPressed: _save,
          child: Text(widget.todo == null ? 'Agregar' : 'Guardar'),
        ),
      ],
    );
  }
}
