import '../models/packing_template_item.dart';
import '../models/trip_context.dart';

class PackingListBuilder {
  PackingListBuilder._();

  static List<String> buildTitles({
    required List<PackingTemplateItem> templates,
    String? destinationId,
    required Set<TripContext> selectedContexts,
  }) {
    final contexts = {...selectedContexts, TripContext.everyTrip};
    final seen = <String>{};
    final ordered = <String>[];

    void addTitle(String title) {
      final key = title.trim().toLowerCase();
      if (key.isEmpty || seen.contains(key)) return;
      seen.add(key);
      ordered.add(title.trim());
    }

    final matching = templates.where((item) {
      if (item.isDestinationSpecific) {
        return item.destinationId == destinationId;
      }

      if (item.tripContexts.isEmpty) {
        return false;
      }

      return item.tripContexts.any(contexts.contains);
    }).toList()
      ..sort((a, b) {
        final order = a.sortOrder.compareTo(b.sortOrder);
        if (order != 0) return order;
        return a.title.toLowerCase().compareTo(b.title.toLowerCase());
      });

    for (final item in matching) {
      addTitle(item.title);
    }

    return ordered;
  }
}
