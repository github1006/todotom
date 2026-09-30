import 'package:flutter/material.dart';

import '../models/place.dart';
import '../models/reminder_sound.dart';
import '../services/notification_service.dart';
import 'place_map_page.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({
    super.key,
    required this.places,
    required this.onPlacesChanged,
    required this.remindersEnabled,
    required this.onRemindersEnabledChanged,
    required this.reminderSound,
    required this.onPickReminderSound,
    required this.onUseDefaultReminderSound,
  });

  final List<Place> places;
  final ValueChanged<List<Place>> onPlacesChanged;
  final bool remindersEnabled;
  final ValueChanged<bool> onRemindersEnabledChanged;
  final ReminderSoundConfig reminderSound;
  final Future<ReminderSoundConfig?> Function() onPickReminderSound;
  final Future<ReminderSoundConfig?> Function() onUseDefaultReminderSound;

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  late List<Place> _places;
  late ReminderSoundConfig _reminderSound;

  @override
  void initState() {
    super.initState();
    _places = List<Place>.from(widget.places);
    _reminderSound = widget.reminderSound;
  }

  @override
  void didUpdateWidget(covariant PlacesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reminderSound != widget.reminderSound) {
      _reminderSound = widget.reminderSound;
    }
  }

  Future<void> _pickReminderSound() async {
    final sound = await widget.onPickReminderSound();
    if (sound == null || !mounted) return;
    setState(() => _reminderSound = sound);
  }

  Future<void> _useDefaultReminderSound() async {
    final sound = await widget.onUseDefaultReminderSound();
    if (sound == null || !mounted) return;
    setState(() => _reminderSound = sound);
  }

  Future<void> _openPlaceEditor({Place? place}) async {
    final result = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => PlaceMapPage(place: place)),
    );

    if (result == null) return;

    final updated = List<Place>.from(_places);
    final index = updated.indexWhere((p) => p.id == result.id);
    if (index >= 0) {
      updated[index] = result;
    } else {
      updated.insert(0, result);
    }

    setState(() => _places = updated);
    widget.onPlacesChanged(updated);
  }

  Future<void> _deletePlace(Place place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar lugar'),
        content: Text('¿Eliminar "${place.name}"? Las tareas quedarán sin lugar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );

    if (confirm != true) return;

    final updated = _places.where((p) => p.id != place.id).toList();
    setState(() => _places = updated);
    widget.onPlacesChanged(updated);
  }

  Future<void> _testSound() async {
    await NotificationService.showTestReminder(sound: _reminderSound);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lugares')),
      body: Column(
        children: [
          SwitchListTile(
            title: const Text('Recordatorios por ubicación'),
            subtitle: const Text('Avisa al llegar a un lugar marcado'),
            value: widget.remindersEnabled,
            onChanged: widget.onRemindersEnabledChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Sonido del aviso', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      _reminderSound.displayLabel,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Usa los mismos tonos que Android (notificaciones, llamadas, alarmas).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _pickReminderSound,
                            icon: const Icon(Icons.library_music_outlined),
                            label: Text(
                              _reminderSound.usesSystemPicker ? 'Cambiar tono' : 'Elegir tono',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: _testSound,
                          tooltip: 'Probar sonido',
                          icon: const Icon(Icons.volume_up_outlined),
                        ),
                      ],
                    ),
                    if (_reminderSound.usesSystemPicker) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: _useDefaultReminderSound,
                          child: const Text('Volver al predeterminado del teléfono'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _places.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.place_outlined,
                            size: 72,
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text('Sin lugares', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text(
                            'Marca en el mapa dónde quieres que te recuerde comprar o hacer algo.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _places.length,
                    itemBuilder: (context, index) {
                      final place = _places[index];
                      return ListTile(
                        leading: const Icon(Icons.place),
                        title: Text(place.name),
                        subtitle: Text('Radio: ${place.radiusMeters.round()} m'),
                        onTap: () => _openPlaceEditor(place: place),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deletePlace(place),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openPlaceEditor(),
        icon: const Icon(Icons.add_location_alt),
        label: const Text('Nuevo lugar'),
      ),
    );
  }
}
