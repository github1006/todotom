import 'package:flutter/material.dart';

import '../../core/app_dependencies.dart';
import '../../models/packing_session.dart';
import '../../utils/date_only.dart';
import 'packing_session_page.dart';

class TripHistoryPage extends StatefulWidget {
  const TripHistoryPage({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<TripHistoryPage> createState() => _TripHistoryPageState();
}

class _TripHistoryPageState extends State<TripHistoryPage> {
  bool _loading = true;
  List<PackingSession> _sessions = [];
  Map<String, String> _destinationNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await widget.dependencies.packingRepository.listTripHistory();
    final destinations = await widget.dependencies.packingRepository.getDestinations();
    final names = {for (final d in destinations) d.id: d.name};

    if (!mounted) return;
    setState(() {
      _sessions = sessions;
      _destinationNames = names;
      _loading = false;
    });
  }

  String _label(PackingSession session) {
    if (session.destinationId == null) return 'Viaje general';
    return _destinationNames[session.destinationId] ?? 'Destino';
  }

  Future<void> _open(PackingSession session) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PackingSessionPage(
          dependencies: widget.dependencies,
          session: session,
        ),
      ),
    );
    await _load();
  }

  Future<void> _confirmDelete(PackingSession session) async {
    final label = _label(session);
    final date = DateOnly.format(session.travelDate);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar viaje'),
        content: Text('¿Quitar de la lista el viaje a $label del $date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await widget.dependencies.packingRepository.deleteSession(session.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Viaje eliminado')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Viajes anteriores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? const Center(child: Text('Aún no hay viajes guardados'))
              : ListView.builder(
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    return FutureBuilder<List<PackingSessionItem>>(
                      future: widget.dependencies.packingRepository.getSessionItems(session.id),
                      builder: (context, snapshot) {
                        final items = snapshot.data ?? const [];
                        final done = items.where((i) => i.done).length;
                        final total = items.length;

                        return ListTile(
                            leading: const Icon(Icons.event_outlined),
                            title: Text(_label(session)),
                            subtitle: Text(
                              '${DateOnly.format(session.travelDate)} · $done/$total en maleta',
                            ),
                            trailing: IconButton(
                              tooltip: 'Eliminar',
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _confirmDelete(session),
                            ),
                            onTap: () => _open(session),
                          );
                      },
                    );
                  },
                ),
    );
  }
}
