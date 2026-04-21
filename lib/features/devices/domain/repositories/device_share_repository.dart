abstract class DeviceSharesRepository {
  Future<int> getPendingInvitationsCount();

  Future<List<Map<String, dynamic>>> getPendingInvitations();

  Future<void> acceptInvitation(String shareId);

  Future<void> rejectInvitation(String shareId);

  Future<Map<String, dynamic>?> fetchDeviceOwnership(String deviceId);

  Future<List<Map<String, dynamic>>> getDeviceShares(String deviceId);

  Future<List<Map<String, dynamic>>> getProfilesByIds(List<String> ids);

  Future<void> inviteDeviceShareByEmail({
    required String deviceId,
    required String email,
  });

  Future<void> revokeDeviceShare(String shareId);

  Future<void> leaveSharedDevice(String shareId);
}
