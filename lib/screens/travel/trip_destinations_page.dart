import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/trip_destination.dart';

class TripDestinationsPage extends StatefulWidget {
  const TripDestinationsPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<TripDestinationsPage> createState() => _TripDestinationsPageState();
}

class _TripDestinationsPageState extends State<TripDestinationsPage> {
  List<TripDestination> _destinations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await widget.dependencies.packingRepository.getDestinations();
    if (!mounted) return;
    setState(() {
      _destinations = list;
      _loading = false;
    });
  }

  Future<void> _edit({TripDestination? destination}) async {
    final nameController = TextEditingController(text: destination?.name ?? '');
    final notesController = TextEditingController(text: destination?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(destination == null ? 'Nuevo destino' : 'Editar destino'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Rayo Rojo, La Paz',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final item = TripDestination(
      id: destination?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim(),
      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
      placeId: destination?.placeId,
    );

    await widget.dependencies.packingRepository.upsertDestination(item);
    await _load();
  }

  Future<void> _delete(TripDestination destination) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar destino'),
        content: Text('¿Eliminar "${destination.name}" y sus ítems de plantilla?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;

    await widget.dependencies.packingRepository.deleteDestination(destination.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Destinos de viaje')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _destinations.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.map_outlined, size: 64),
                        const SizedBox(height: 16),
                        const Text('Sin destinos', textAlign: TextAlign.center),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea Rayo Rojo, La Paz u otros lugares donde viajas seguido.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _destinations.length,
                  itemBuilder: (context, index) {
                    final d = _destinations[index];
                    return ListTile(
                      leading: const Icon(Icons.flag_outlined),
                      title: Text(d.name),
                      subtitle: d.notes == null ? null : Text(d.notes!),
                      onTap: () => _edit(destination: d),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(d),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Destino'),
      ),
    );
  }
}
