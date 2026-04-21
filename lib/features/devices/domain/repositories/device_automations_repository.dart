abstract class DeviceAutomationsRepository {
  Future<List<Map<String, dynamic>>> fetchAutomations({
    required String deviceId,
    required String type,
  });

  Future<void> upsertAutomation({
    String? id,
    required String deviceId,
    required String type,
    required bool enabled,
    required Map<String, dynamic> config,
  });

  Future<void> deleteAutomation(String automationId);
}
