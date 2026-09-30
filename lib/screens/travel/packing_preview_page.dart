import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/packing_preview_item.dart';
import '../../models/packing_session.dart';
import '../../models/trip_context.dart';
import '../../services/packing_list_builder.dart';
import '../../utils/date_only.dart';

class PackingPreviewPage extends StatefulWidget {
  const PackingPreviewPage({
    super.key,
    required this.dependencies,
    required this.travelDate,
    required this.destinationId,
    required this.destinationLabel,
    required this.tripContexts,
  });

  final AppDependencies dependencies;
  final DateTime travelDate;
  final String? destinationId;
  final String destinationLabel;
  final Set<TripContext> tripContexts;

  @override
  State<PackingPreviewPage> createState() => _PackingPreviewPageState();
}

class _PackingPreviewPageState extends State<PackingPreviewPage> {
  bool _loading = true;
  List<PackingPreviewItem> _items = [];
  List<String> _templateTitles = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);

    final templates = await widget.dependencies.packingRepository.getTemplateItems();
    final titles = PackingListBuilder.buildTitles(
      templates: templates,
      destinationId: widget.destinationId,
      selectedContexts: widget.tripContexts,
    );
    _templateTitles = titles;

    if (titles.isEmpty) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
      });
      return;
    }

    final existing = await widget.dependencies.packingRepository.findSessionForDate(
      destinationId: widget.destinationId,
      travelDate: widget.travelDate,
    );

    if (existing != null) {
      final session = await widget.dependencies.packingRepository.ensureSession(
        destinationId: widget.destinationId,
        travelDate: widget.travelDate,
        tripContexts: widget.tripContexts.toList(),
        titles: titles,
      );
      final sessionItems = await widget.dependencies.packingRepository.getSessionItems(session.id);
      if (!mounted) return;
      setState(() {
        _items = sessionItems
            .map(
              (item) => PackingPreviewItem(
                title: item.title,
                done: item.done,
                itemId: item.id,
              ),
            )
            .toList();
        _loading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _items = titles.map((title) => PackingPreviewItem(title: title, done: false)).toList();
      _loading = false;
    });
  }

  Future<void> _toggle(PackingPreviewItem item) async {
    if (_templateTitles.isEmpty) return;

    final session = await widget.dependencies.packingRepository.ensureSession(
      destinationId: widget.destinationId,
      travelDate: widget.travelDate,
      tripContexts: widget.tripContexts.toList(),
      titles: _templateTitles,
    );
    final sessionItems = await widget.dependencies.packingRepository.getSessionItems(session.id);

    PackingSessionItem target;
    if (item.itemId != null) {
      target = sessionItems.firstWhere((i) => i.id == item.itemId);
    } else {
      target = sessionItems.firstWhere(
        (i) => i.title.toLowerCase() == item.title.toLowerCase(),
      );
    }

    await widget.dependencies.packingRepository.setSessionItemDone(target.id, !target.done);
    await _load();
  }

  int get _doneCount => _items.where((item) => item.done).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.destinationLabel),
            Text(
              '${DateOnly.format(widget.travelDate)} · $_doneCount/${_items.length} en maleta',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('No hay ítems para mostrar'))
              : Scrollbar(
                  thumbVisibility: true,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return ListTile(
                        leading: Icon(
                          item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                          color: item.done ? colorScheme.primary : colorScheme.outline,
                        ),
                        title: Text(
                          item.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            decoration: item.done ? TextDecoration.lineThrough : null,
                            color: item.done ? colorScheme.onSurfaceVariant : null,
                          ),
                        ),
                        onTap: () => _toggle(item),
                      );
                    },
                  ),
                ),
    );
  }
}
