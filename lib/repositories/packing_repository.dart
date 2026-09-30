import '../models/packing_session.dart';
import '../models/packing_template_item.dart';
import '../models/trip_context.dart';
import '../models/trip_destination.dart';

abstract class PackingRepository {
  Future<List<TripDestination>> getDestinations();
  Future<void> upsertDestination(TripDestination destination);
  Future<void> deleteDestination(String id);

  Future<List<PackingTemplateItem>> getTemplateItems();
  Future<void> upsertTemplateItem(PackingTemplateItem item);
  Future<void> deleteTemplateItem(String id);

  Future<String?> getLastUsedTripDestinationId();

  Future<PackingSession?> findSessionForDate({
    String? destinationId,
    required DateTime travelDate,
  });

  Future<PackingSession?> getLatestOpenSession({DateTime? travelDate});

  Future<List<PackingSession>> listTripHistory({int limit = 40});

  Future<List<PackingSessionItem>> getSessionItems(String sessionId);

  Future<PackingSession> ensureSession({
    String? destinationId,
    required DateTime travelDate,
    required List<TripContext> tripContexts,
    required List<String> titles,
  });

  Future<void> setSessionItemDone(String itemId, bool done);

  Future<void> deleteSession(String sessionId);
}
