abstract class DeviceIncidentsRepository {
  Future<bool> hasActiveIncidents(String deviceId);

  Future<Map<String, dynamic>?> getLatestActiveIncident(String deviceId);

  Future<List<Map<String, dynamic>>> getActiveIncidentsByTypes({
    required String deviceId,
    required List<String> types,
  });

  Future<void> acknowledgeIncident(String incidentId);

  Future<void> resolveIncident(String incidentId);

  Future<void> resolveIncidents(List<String> incidentIds);

  Future<void> insertIncident({
    required String deviceId,
    required String type,
    required String message,
    int severity = 3,
  });

  Future<List<Map<String, dynamic>>> fetchIncidents({
    required String deviceId,
    int limit = 100,
  });
}
