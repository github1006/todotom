import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../models/place.dart';

String _newPlaceId() {
  return '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';
}

class PlaceMapPage extends StatefulWidget {
  const PlaceMapPage({super.key, this.place});

  final Place? place;

  @override
  State<PlaceMapPage> createState() => _PlaceMapPageState();
}

class _PlaceMapPageState extends State<PlaceMapPage> {
  final _nameController = TextEditingController();
  final _mapController = MapController();

  LatLng? _selected;
  double _radius = 250;
  bool _loadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.place != null) {
      _nameController.text = widget.place!.name;
      _selected = LatLng(widget.place!.latitude, widget.place!.longitude);
      _radius = widget.place!.radiusMeters;
    } else {
      _initCurrentLocation();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _selected = LatLng(position.latitude, position.longitude));
      _mapController.move(_selected!, 16);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selected = const LatLng(40.4168, -3.7038));
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _useMyLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _selected = LatLng(position.latitude, position.longitude));
      _mapController.move(_selected!, 16);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener tu ubicación')),
      );
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para el lugar')),
      );
      return;
    }
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marca un punto en el mapa')),
      );
      return;
    }

    final place = Place(
      id: widget.place?.id ?? _newPlaceId(),
      name: name,
      latitude: _selected!.latitude,
      longitude: _selected!.longitude,
      radiusMeters: _radius,
    );

    Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) {
    final center = _selected ?? const LatLng(40.4168, -3.7038);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.place == null ? 'Nuevo lugar' : 'Editar lugar'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Guardar')),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del lugar',
                    hintText: 'Ej. Ferretería, Supermercado...',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  autocorrect: false,
                  enableSuggestions: false,
                ),
                const SizedBox(height: 12),
                Text('Radio de aviso: ${_radius.round()} m'),
                Slider(
                  value: _radius,
                  min: 100,
                  max: 500,
                  divisions: 8,
                  label: '${_radius.round()} m',
                  onChanged: (value) => setState(() => _radius = value),
                ),
                OutlinedButton.icon(
                  onPressed: _loadingLocation ? null : _useMyLocation,
                  icon: _loadingLocation
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text('Usar mi ubicación actual'),
                ),
              ],
            ),
          ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 16,
                onTap: (_, point) => setState(() => _selected = point),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.todotom',
                ),
                if (_selected != null)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: _selected!,
                        radius: _radius,
                        useRadiusInMeter: true,
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                        borderColor: Theme.of(context).colorScheme.primary,
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selected!,
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.location_on,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Toca el mapa donde quieres que te recuerde. El círculo muestra la zona de aviso.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
