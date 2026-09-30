/// Contexto del viaje para combinar ítems de la maleta.
enum TripContext {
  everyTrip,
  cityToField,
  fieldToCity,
  fieldDay,
}

extension TripContextLabels on TripContext {
  String get label {
    switch (this) {
      case TripContext.everyTrip:
        return 'Siempre (cualquier viaje)';
      case TripContext.cityToField:
        return 'Ciudad → campo/provincia';
      case TripContext.fieldToCity:
        return 'Campo/provincia → ciudad';
      case TripContext.fieldDay:
        return 'Día de campo';
    }
  }

  String get chipLabel {
    switch (this) {
      case TripContext.everyTrip:
        return 'Siempre';
      case TripContext.cityToField:
        return '→ Campo';
      case TripContext.fieldToCity:
        return '→ Ciudad';
      case TripContext.fieldDay:
        return 'Día campo';
    }
  }

  String get storageKey {
    switch (this) {
      case TripContext.everyTrip:
        return 'every_trip';
      case TripContext.cityToField:
        return 'city_to_field';
      case TripContext.fieldToCity:
        return 'field_to_city';
      case TripContext.fieldDay:
        return 'field_day';
    }
  }
}

class TripContextStorage {
  TripContextStorage._();

  static TripContext? fromKey(String key) {
    for (final value in TripContext.values) {
      if (value.storageKey == key) return value;
    }
    return null;
  }

  static List<String> toKeys(Iterable<TripContext> contexts) {
    return contexts.map((c) => c.storageKey).toList();
  }

  static List<TripContext> fromKeys(Iterable<String> keys) {
    return keys.map(fromKey).whereType<TripContext>().toList();
  }
}
