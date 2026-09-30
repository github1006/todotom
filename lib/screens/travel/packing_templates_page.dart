import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/packing_template_item.dart';
import '../../models/trip_context.dart';
import '../../models/trip_destination.dart';

class PackingTemplatesPage extends StatefulWidget {
  const PackingTemplatesPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<PackingTemplatesPage> createState() => _PackingTemplatesPageState();
}

class _PackingTemplatesPageState extends State<PackingTemplatesPage> {
  List<PackingTemplateItem> _items = [];
  List<TripDestination> _destinations = [];
  String? _lastDestinationId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.dependencies.packingRepository.getTemplateItems();
    final destinations = await widget.dependencies.packingRepository.getDestinations();
    final lastDestinationId =
        await widget.dependencies.settingsRepository.getLastPackingDestinationId();
    if (!mounted) return;
    setState(() {
      _items = items;
      _destinations = destinations;
      _lastDestinationId = _resolveDestinationId(lastDestinationId, destinations);
      _loading = false;
    });
  }

  String? _resolveDestinationId(String? id, List<TripDestination> destinations) {
    if (id == null) return null;
    for (final destination in destinations) {
      if (destination.id == id) return id;
    }
    return null;
  }

  String _destinationName(String? id) {
    if (id == null) return '';
    for (final d in _destinations) {
      if (d.id == id) return d.name;
    }
    return 'Destino';
  }

  String _subtitle(PackingTemplateItem item) {
    if (item.isDestinationSpecific) {
      return 'Solo ${_destinationName(item.destinationId)}';
    }
    if (item.tripContexts.isEmpty) {
      return 'Sin contexto';
    }
    return item.tripContexts.map((c) => c.label).join(' · ');
  }

  Future<void> _edit({PackingTemplateItem? item}) async {
    final titleController = TextEditingController(text: item?.title ?? '');
    String? destinationId = item?.destinationId ?? _lastDestinationId;
    final selectedContexts = {...?item?.tripContexts};

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(item == null ? 'Nuevo ítem' : 'Editar ítem'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Qué llevar',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: destinationId,
                    decoration: const InputDecoration(
                      labelText: 'Destino específico (opcional)',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Cualquier destino')),
                      ..._destinations.map(
                        (d) => DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ),
                    ],
                    onChanged: (value) => setDialogState(() => destinationId = value),
                  ),
                  if (destinationId == null) ...[
                    const SizedBox(height: 8),
                    const Text('Tipo de viaje (si no es por destino):'),
                    ...TripContext.values.map(
                      (tripContext) => CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tripContext.label),
                        value: selectedContexts.contains(tripContext),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedContexts.add(tripContext);
                            } else {
                              selectedContexts.remove(tripContext);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  Navigator.pop(context, true);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final template = PackingTemplateItem(
      id: item?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      title: titleController.text.trim(),
      destinationId: destinationId,
      tripContexts: destinationId == null ? selectedContexts.toList() : const [],
    );

    await widget.dependencies.packingRepository.upsertTemplateItem(template);
    await widget.dependencies.settingsRepository.setLastPackingDestinationId(destinationId);
    if (!mounted) return;
    setState(() => _lastDestinationId = destinationId);
    await _load();
  }

  Future<void> _delete(PackingTemplateItem item) async {
    await widget.dependencies.packingRepository.deleteTemplateItem(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas maleta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Añade ítems o usa “Cargar ejemplos” en la pantalla anterior.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(item.title),
                      subtitle: Text(_subtitle(item)),
                      onTap: () => _edit(item: item),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(item),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Ítem'),
      ),
    );
  }
}
