import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/packing_preview_item.dart';
import '../../models/packing_session.dart';
import '../../models/trip_context.dart';
import '../../models/trip_destination.dart';
import '../../services/packing_list_builder.dart';
import '../../services/packing_suggestions.dart';
import '../../utils/date_only.dart';
import 'packing_session_page.dart';
import 'packing_templates_page.dart';
import 'trip_destinations_page.dart';
import 'packing_preview_page.dart';
import 'trip_history_page.dart';

class TravelHubPage extends StatefulWidget {
  const TravelHubPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<TravelHubPage> createState() => TravelHubPageState();
}

class TravelHubPageState extends State<TravelHubPage> {
  bool _loading = true;
  PackingSession? _activeSession;
  List<TripDestination> _destinations = [];
  String? _destinationId;
  DateTime _travelDate = DateOnly.today();
  Set<TripContext> _contexts = {TripContext.cityToField};
  List<PackingPreviewItem> _previewItems = [];
  List<String> _templateTitles = [];
  bool _starting = false;

  static const _selectableContexts = [
    TripContext.cityToField,
    TripContext.fieldToCity,
    TripContext.fieldDay,
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    setState(() => _loading = true);

    final destinations = await widget.dependencies.packingRepository.getDestinations();
    final lastContexts = await widget.dependencies.settingsRepository.getLastPackingTripContexts();
    final resolvedDestinationId = await _initialDestinationId(destinations);

    if (!mounted) return;
    setState(() {
      _destinations = destinations;
      _destinationId = resolvedDestinationId;
      _contexts = {...lastContexts};
      _loading = false;
    });

    await _refreshActiveSession();
    await _refreshPreview();
  }

  Future<void> _refreshActiveSession() async {
    final session = await widget.dependencies.packingRepository.getLatestOpenSession(
      travelDate: _travelDate,
    );
    if (!mounted) return;
    setState(() => _activeSession = session);
  }

  String? _resolveDestinationId(String? id, List<TripDestination> destinations) {
    if (id == null) return null;
    for (final destination in destinations) {
      if (destination.id == id) return id;
    }
    return null;
  }

  Future<String?> _initialDestinationId(List<TripDestination> destinations) async {
    final settings = widget.dependencies.settingsRepository;
    final packing = widget.dependencies.packingRepository;

    final fromTripPref = _resolveDestinationId(
      await settings.getLastTripDestinationId(),
      destinations,
    );
    if (fromTripPref != null) return fromTripPref;

    final fromLastSession = _resolveDestinationId(
      await packing.getLastUsedTripDestinationId(),
      destinations,
    );
    if (fromLastSession != null) return fromLastSession;

    final fromTemplatePref = _resolveDestinationId(
      await settings.getLastPackingDestinationId(),
      destinations,
    );
    if (fromTemplatePref != null) return fromTemplatePref;

    if (destinations.length == 1) return destinations.first.id;
    return null;
  }

  Future<void> _refreshPreview() async {
    final templates = await widget.dependencies.packingRepository.getTemplateItems();
    final titles = PackingListBuilder.buildTitles(
      templates: templates,
      destinationId: _destinationId,
      selectedContexts: _contexts,
    );

    _templateTitles = titles;

    if (titles.isEmpty) {
      if (!mounted) return;
      setState(() => _previewItems = []);
      return;
    }

    final existing = await widget.dependencies.packingRepository.findSessionForDate(
      destinationId: _destinationId,
      travelDate: _travelDate,
    );

    if (existing != null) {
      final session = await widget.dependencies.packingRepository.ensureSession(
        destinationId: _destinationId,
        travelDate: _travelDate,
        tripContexts: _contexts.toList(),
        titles: titles,
      );
      final items = await widget.dependencies.packingRepository.getSessionItems(session.id);
      if (!mounted) return;
      setState(() {
        _previewItems = items
            .map(
              (item) => PackingPreviewItem(
                title: item.title,
                done: item.done,
                itemId: item.id,
              ),
            )
            .toList();
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _previewItems = titles
          .map((title) => PackingPreviewItem(title: title, done: false))
          .toList();
    });
  }

  Future<void> _persistTripPreferences({bool includeDestination = false}) async {
    if (includeDestination && _destinationId != null) {
      await widget.dependencies.settingsRepository.setLastTripDestinationId(_destinationId!);
    }
    await widget.dependencies.settingsRepository.setLastPackingTripContexts(_contexts);
  }

  Future<void> _selectDestination(String? id) async {
    setState(() => _destinationId = id);
    await _persistTripPreferences(includeDestination: id != null);
    await _refreshActiveSession();
    await _refreshPreview();
  }

  Future<void> _toggleContext(TripContext context, bool selected) async {
    setState(() {
      if (selected) {
        _contexts.add(context);
      } else if (_contexts.length > 1) {
        _contexts.remove(context);
      }
    });
    await _persistTripPreferences();
    await _refreshPreview();
  }

  Future<void> _pickTravelDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _travelDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Fecha del viaje',
    );
    if (picked == null || !mounted) return;

    setState(() => _travelDate = DateOnly.from(picked));
    await _refreshActiveSession();
    await _refreshPreview();
  }

  Future<PackingSession> _ensureSession() async {
    return widget.dependencies.packingRepository.ensureSession(
      destinationId: _destinationId,
      travelDate: _travelDate,
      tripContexts: _contexts.toList(),
      titles: _templateTitles,
    );
  }

  Future<void> _togglePreviewItem(PackingPreviewItem item) async {
    if (_templateTitles.isEmpty) return;

    final session = await _ensureSession();
    final items = await widget.dependencies.packingRepository.getSessionItems(session.id);

    PackingSessionItem target;
    if (item.itemId != null) {
      target = items.firstWhere((i) => i.id == item.itemId);
    } else {
      target = items.firstWhere(
        (i) => i.title.toLowerCase() == item.title.toLowerCase(),
      );
    }

    await widget.dependencies.packingRepository.setSessionItemDone(target.id, !target.done);
    await _refreshActiveSession();
    await _refreshPreview();
  }

  Future<void> _openChecklist(PackingSession session) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PackingSessionPage(
          dependencies: widget.dependencies,
          session: session,
        ),
      ),
    );
    await _refreshActiveSession();
    await _refreshPreview();
  }

  Future<void> _startPacking() async {
    if (_templateTitles.isEmpty || _starting) return;

    setState(() => _starting = true);
    try {
      await _persistTripPreferences(includeDestination: _destinationId != null);
      final session = await _ensureSession();
      if (!mounted) return;
      await _openChecklist(session);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _seedSuggestions() async {
    final added = await PackingSuggestions(widget.dependencies.packingRepository).seedIfEmpty();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Listo: Rayo Rojo, La Paz e ítems de ejemplo'
              : 'Ya tienes datos; edítalos en Plantillas',
        ),
      ),
    );
    await _load();
  }

  Future<void> _openDestinations() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TripDestinationsPage(dependencies: widget.dependencies),
      ),
    );
    await _load();
  }

  Future<void> _openTemplates() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PackingTemplatesPage(dependencies: widget.dependencies),
      ),
    );
    await _refreshPreview();
  }

  Future<void> _openExpandedPreview() async {
    if (_previewItems.isEmpty) return;

    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PackingPreviewPage(
          dependencies: widget.dependencies,
          travelDate: _travelDate,
          destinationId: _destinationId,
          destinationLabel: _destinationName != null ? 'Para $_destinationName' : 'Lista general',
          tripContexts: _contexts,
        ),
      ),
    );
    await _refreshActiveSession();
    await _refreshPreview();
  }

  Future<void> _openHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => TripHistoryPage(dependencies: widget.dependencies),
      ),
    );
    await _refreshPreview();
  }

  String? get _destinationName {
    if (_destinationId == null) return null;
    for (final d in _destinations) {
      if (d.id == _destinationId) return d.name;
    }
    return null;
  }

  int get _doneCount => _previewItems.where((item) => item.done).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Maleta'),
        actions: [
          PopupMenuButton<_TravelMenu>(
            onSelected: (item) async {
              switch (item) {
                case _TravelMenu.destinations:
                  await _openDestinations();
                case _TravelMenu.templates:
                  await _openTemplates();
                case _TravelMenu.history:
                  await _openHistory();
                case _TravelMenu.examples:
                  await _seedSuggestions();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: _TravelMenu.destinations, child: Text('Destinos')),
              PopupMenuItem(value: _TravelMenu.templates, child: Text('Plantillas')),
              PopupMenuItem(value: _TravelMenu.history, child: Text('Viajes anteriores')),
              PopupMenuItem(value: _TravelMenu.examples, child: Text('Cargar ejemplos')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_activeSession != null)
                  Material(
                    color: colorScheme.primaryContainer,
                    child: InkWell(
                      onTap: () => _openChecklist(_activeSession!),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Icon(Icons.playlist_add_check, color: colorScheme.onPrimaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Continuar ${DateOnly.format(_travelDate)} · '
                                '${_activeSession!.destinationId != null ? (_destinationName ?? 'destino') : 'general'}',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right, color: colorScheme.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: const Text('Fecha del viaje'),
                        subtitle: Text(DateOnly.format(_travelDate)),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: _pickTravelDate,
                      ),
                      const SizedBox(height: 8),
                      Text('Destino', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('General'),
                            selected: _destinationId == null,
                            onSelected: (selected) {
                              if (selected) _selectDestination(null);
                            },
                          ),
                          ..._destinations.map(
                            (d) => ChoiceChip(
                              label: Text(d.name),
                              selected: _destinationId == d.id,
                              onSelected: (selected) {
                                if (selected) _selectDestination(d.id);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_destinations.isEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _seedSuggestions,
                          icon: const Icon(Icons.auto_fix_high),
                          label: const Text('Cargar Rayo Rojo y La Paz'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Tipo de viaje', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectableContexts.map((tripContext) {
                          final selected = _contexts.contains(tripContext);
                          return FilterChip(
                            label: Text(tripContext.chipLabel),
                            selected: selected,
                            onSelected: (value) => _toggleContext(tripContext, value),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: colorScheme.surfaceContainerHighest,
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _destinationName != null
                                              ? 'Para $_destinationName'
                                              : 'Lista general',
                                          style: theme.textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Text(
                                          '${DateOnly.format(_travelDate)} · '
                                          '$_doneCount/${_previewItems.length} en maleta',
                                          style: theme.textTheme.bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_previewItems.isNotEmpty)
                                    IconButton(
                                      tooltip: 'Ver lista completa',
                                      onPressed: _openExpandedPreview,
                                      icon: const Icon(Icons.open_in_full),
                                    ),
                                ],
                              ),
                            ),
                            if (_previewItems.isEmpty)
                              const Padding(
                                padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Text('Elige destino o tipo de viaje, o añade plantillas.'),
                              )
                            else
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 280),
                                child: Scrollbar(
                                  thumbVisibility: _previewItems.length > 6,
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _previewItems.length,
                                    itemBuilder: (context, index) {
                                      final item = _previewItems[index];
                                      return InkWell(
                                        onTap: () => _togglePreviewItem(item),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                item.done
                                                    ? Icons.check_circle
                                                    : Icons.radio_button_unchecked,
                                                size: 22,
                                                color: item.done
                                                    ? colorScheme.primary
                                                    : colorScheme.outline,
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: theme.textTheme.bodyMedium?.copyWith(
                                                    decoration: item.done
                                                        ? TextDecoration.lineThrough
                                                        : null,
                                                    color: item.done
                                                        ? colorScheme.onSurfaceVariant
                                                        : null,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      onPressed: _previewItems.isEmpty || _starting ? null : _startPacking,
                      icon: _starting
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.luggage),
                      label: Text(
                        _previewItems.isEmpty
                            ? 'Sin ítems para alistar'
                            : 'Abrir checklist (${_previewItems.length})',
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        textStyle: theme.textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

enum _TravelMenu { destinations, templates, history, examples }
