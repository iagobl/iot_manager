class DiscoveredIotDevice {

  const DiscoveredIotDevice({
    required this.ip,
    required this.name,
    required this.type,
    required this.deviceInfo,
  });
  final String ip;
  final String name;
  final String type;
  final Map<String, dynamic> deviceInfo;
}