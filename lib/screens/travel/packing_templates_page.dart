import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/packing_template_item.dart';
import '../../models/trip_context.dart';
import '../../models/trip_destination.dart';

class PackingTemplatesPage extends StatefulWidget {
  const PackingTemplatesPage({
    super.key,
    required this.dependencies,
    this.initialDestinationId,
  });

  final AppDependencies dependencies;
  final String? initialDestinationId;

  @override
  State<PackingTemplatesPage> createState() => _PackingTemplatesPageState();
}

class _PackingTemplatesPageState extends State<PackingTemplatesPage> {
  List<PackingTemplateItem> _items = [];
  List<TripDestination> _destinations = [];
  String? _selectedDestinationId;
  bool _loading = true;

  bool get _editingGlobal => _selectedDestinationId == null;

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

    final preferred = widget.initialDestinationId ?? lastDestinationId;
    final resolved = _resolveDestinationId(preferred, destinations);

    if (!mounted) return;
    setState(() {
      _items = items;
      _destinations = destinations;
      _selectedDestinationId = resolved ?? (destinations.length == 1 ? destinations.first.id : resolved);
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

  List<PackingTemplateItem> get _visibleItems {
    if (_editingGlobal) {
      return _items.where((item) => !item.isDestinationSpecific).toList()
        ..sort(_sortTemplates);
    }
    return _items.where((item) => item.destinationId == _selectedDestinationId).toList()
      ..sort(_sortTemplates);
  }

  int _sortTemplates(PackingTemplateItem a, PackingTemplateItem b) {
    final order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  String _subtitle(PackingTemplateItem item) {
    if (item.isDestinationSpecific) {
      return 'Solo ${_destinationName(item.destinationId)}';
    }
    if (item.tripContexts.contains(TripContext.everyTrip)) {
      return 'En todos los viajes';
    }
    if (item.tripContexts.isEmpty) {
      return 'Sin contexto';
    }
    return item.tripContexts.map((c) => c.label).join(' · ');
  }

  Future<void> _selectDestination(String? id) async {
    setState(() => _selectedDestinationId = id);
    await widget.dependencies.settingsRepository.setLastPackingDestinationId(id);
  }

  Future<void> _edit({PackingTemplateItem? item}) async {
    final titleController = TextEditingController(text: item?.title ?? '');
    final destinationId = item?.destinationId ?? _selectedDestinationId;
    final editingGlobal = destinationId == null;
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
                  if (!editingGlobal)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Destino: ${_destinationName(destinationId)}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Qué llevar',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  if (editingGlobal) ...[
                    const SizedBox(height: 12),
                    const Text('Cuándo aplica (viaje general sin destino fijo):'),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('En todos los viajes'),
                      subtitle: const Text('Llaves, cargador, etc.'),
                      value: selectedContexts.contains(TripContext.everyTrip),
                      onChanged: (checked) {
                        setDialogState(() {
                          if (checked == true) {
                            selectedContexts
                              ..clear()
                              ..add(TripContext.everyTrip);
                          } else {
                            selectedContexts.remove(TripContext.everyTrip);
                          }
                        });
                      },
                    ),
                    if (!selectedContexts.contains(TripContext.everyTrip)) ...[
                      const Text('O solo según tipo de viaje:'),
                      ...TripContext.values.where((c) => c != TripContext.everyTrip).map(
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
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () {
                  if (titleController.text.trim().isEmpty) return;
                  if (editingGlobal &&
                      !selectedContexts.contains(TripContext.everyTrip) &&
                      selectedContexts.isEmpty) {
                    return;
                  }
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
      destinationId: editingGlobal ? null : destinationId,
      tripContexts: editingGlobal ? selectedContexts.toList() : const [],
    );

    await widget.dependencies.packingRepository.upsertTemplateItem(template);
    await widget.dependencies.settingsRepository.setLastPackingDestinationId(destinationId);
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(PackingTemplateItem item) async {
    await widget.dependencies.packingRepository.deleteTemplateItem(item.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visible = _visibleItems;
    final headerLabel = _editingGlobal
        ? 'Cosas en todos los viajes'
        : 'Plantilla para ${_destinationName(_selectedDestinationId)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas maleta')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text('¿Para qué destino?', style: theme.textTheme.titleSmall),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text('Todos los viajes'),
                          selected: _editingGlobal,
                          onSelected: (selected) {
                            if (selected) _selectDestination(null);
                          },
                        ),
                      ),
                      ..._destinations.map(
                        (d) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(d.name),
                            selected: _selectedDestinationId == d.id,
                            onSelected: (selected) {
                              if (selected) _selectDestination(d.id);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    headerLabel,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (!_editingGlobal)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Estos ítems solo aparecen cuando eliges este destino en Maleta.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                if (_editingGlobal)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Se suman a cualquier destino (o al modo General en Maleta).',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              _destinations.isEmpty
                                  ? 'Primero crea destinos en Menú → Destinos, o usa “Cargar ejemplos”.'
                                  : 'Aún no hay ítems aquí. Pulsa + para añadir.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final item = visible[index];
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
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _destinations.isEmpty && !_editingGlobal ? null : () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Ítem'),
      ),
    );
  }
}
