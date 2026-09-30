import '../models/packing_template_item.dart';
import '../models/trip_context.dart';
import '../models/trip_destination.dart';
import '../repositories/packing_repository.dart';

/// Ejemplos iniciales basados en viajes frecuentes (editable después).
class PackingSuggestions {
  PackingSuggestions(this._repository);

  final PackingRepository _repository;

  Future<bool> seedIfEmpty() async {
    final destinations = await _repository.getDestinations();
    final templates = await _repository.getTemplateItems();
    if (destinations.isNotEmpty || templates.isNotEmpty) {
      return false;
    }

    final rayoRojo = TripDestination(
      id: 'dest_rayo_rojo',
      name: 'Rayo Rojo',
    );
    final laPaz = TripDestination(
      id: 'dest_la_paz',
      name: 'La Paz',
    );

    await _repository.upsertDestination(rayoRojo);
    await _repository.upsertDestination(laPaz);

    final items = <PackingTemplateItem>[
      PackingTemplateItem(
        id: 'tpl_llaves',
        title: 'Llaves',
        tripContexts: [TripContext.everyTrip],
      ),
      PackingTemplateItem(
        id: 'tpl_cargador',
        title: 'Cargador de celular',
        tripContexts: [TripContext.everyTrip],
      ),
      PackingTemplateItem(
        id: 'tpl_mouse',
        title: 'Mouse',
        destinationId: rayoRojo.id,
      ),
      PackingTemplateItem(
        id: 'tpl_botas',
        title: 'Botas',
        destinationId: rayoRojo.id,
      ),
      PackingTemplateItem(
        id: 'tpl_cinturon',
        title: 'Cinturón',
        tripContexts: [TripContext.everyTrip],
      ),
      PackingTemplateItem(
        id: 'tpl_medicamentos_adriana',
        title: 'Medicamentos para tía Adriana',
        destinationId: laPaz.id,
      ),
      PackingTemplateItem(
        id: 'tpl_agua',
        title: 'Agua',
        destinationId: rayoRojo.id,
      ),
      PackingTemplateItem(
        id: 'tpl_gorra',
        title: 'Gorra / sombrero',
        destinationId: rayoRojo.id,
      ),
      PackingTemplateItem(
        id: 'tpl_documentos',
        title: 'Documentos / carnet',
        destinationId: rayoRojo.id,
      ),
      PackingTemplateItem(
        id: 'tpl_linterna',
        title: 'Linterna',
        destinationId: rayoRojo.id,
      ),
    ];

    for (final item in items) {
      await _repository.upsertTemplateItem(item);
    }

    return true;
  }
}
