import 'package:flutter_test/flutter_test.dart';
import 'package:todotom/models/packing_template_item.dart';
import 'package:todotom/models/trip_context.dart';
import 'package:todotom/services/packing_list_builder.dart';

void main() {
  test('combina ítems del destino y del contexto', () {
    const laPazId = 'la_paz';
    final templates = [
      PackingTemplateItem(
        id: '1',
        title: 'Llaves',
        tripContexts: [TripContext.everyTrip],
      ),
      PackingTemplateItem(
        id: '2',
        title: 'Medicamentos tía',
        destinationId: laPazId,
      ),
      PackingTemplateItem(
        id: '3',
        title: 'Botas',
        tripContexts: [TripContext.fieldDay],
      ),
    ];

    final titles = PackingListBuilder.buildTitles(
      templates: templates,
      destinationId: laPazId,
      selectedContexts: {TripContext.fieldDay},
    );

    expect(titles, containsAll(['Llaves', 'Medicamentos tía', 'Botas']));
    expect(titles.length, 3);
  });

  test('no duplica títulos', () {
    final templates = [
      PackingTemplateItem(
        id: '1',
        title: 'Cargador',
        tripContexts: [TripContext.everyTrip],
      ),
      PackingTemplateItem(
        id: '2',
        title: 'cargador',
        tripContexts: [TripContext.cityToField],
      ),
    ];

    final titles = PackingListBuilder.buildTitles(
      templates: templates,
      destinationId: null,
      selectedContexts: {TripContext.cityToField},
    );

    expect(titles, ['Cargador']);
  });
}
