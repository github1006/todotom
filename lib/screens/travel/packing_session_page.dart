import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/packing_session.dart';
import '../../utils/date_only.dart';

class PackingSessionPage extends StatefulWidget {
  const PackingSessionPage({
    super.key,
    required this.dependencies,
    required this.session,
  });

  final AppDependencies dependencies;
  final PackingSession session;

  @override
  State<PackingSessionPage> createState() => _PackingSessionPageState();
}

class _PackingSessionPageState extends State<PackingSessionPage> {
  List<PackingSessionItem> _items = [];
  String _destinationLabel = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await widget.dependencies.packingRepository.getSessionItems(widget.session.id);
    var label = 'Viaje general';
    if (widget.session.destinationId != null) {
      final destinations = await widget.dependencies.packingRepository.getDestinations();
      for (final d in destinations) {
        if (d.id == widget.session.destinationId) {
          label = d.name;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _items = items;
      _destinationLabel = label;
      _loading = false;
    });
  }

  Future<void> _toggle(PackingSessionItem item) async {
    final next = !item.done;
    setState(() => item.done = next);
    await widget.dependencies.packingRepository.setSessionItemDone(item.id, next);
    setState(() {});
  }

  int get _pending => _items.where((i) => !i.done).length;
  int get _done => _items.length - _pending;

  double get _progress {
    if (_items.isEmpty) return 0;
    return _done / _items.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_destinationLabel),
            Text(
              DateOnly.format(widget.session.travelDate),
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _pending == 0 ? '¡Listo para salir!' : '$_pending por meter',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text('$_done/${_items.length}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 88),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        elevation: 0,
                        color: item.done
                            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                            : colorScheme.surfaceContainerLow,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _toggle(item),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: item.done,
                                  onChanged: (_) => _toggle(item),
                                ),
                                Expanded(
                                  child: Text(
                                    item.title,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      decoration: item.done ? TextDecoration.lineThrough : null,
                                      color: item.done
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _pending == 0 && _items.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Terminar'),
                ),
              ),
            )
          : null,
    );
  }
}
