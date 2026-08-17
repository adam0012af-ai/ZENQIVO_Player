import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceIdentity {
  const DeviceIdentity({required this.deviceId, required this.deviceKey});

  final String deviceId;
  final String deviceKey;
}

class DeviceIdentityService {
  const DeviceIdentityService();

  static const _idKey = 'zenqivo.device_id';
  static const _deviceKeyKey = 'zenqivo.device_key';

  Future<DeviceIdentity> getOrCreate() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_idKey);
    final savedKey = prefs.getString(_deviceKeyKey);
    if (savedId != null && savedKey != null) {
      return DeviceIdentity(deviceId: savedId, deviceKey: savedKey);
    }

    final random = Random.secure();
    String hex(int length) => List.generate(
          length,
          (_) => random.nextInt(16).toRadixString(16).toUpperCase(),
        ).join();

    final identity = DeviceIdentity(
      deviceId: 'ZQ-${hex(4)}-${hex(4)}-${hex(4)}',
      deviceKey: '${hex(4)}-${hex(4)}',
    );
    await prefs.setString(_idKey, identity.deviceId);
    await prefs.setString(_deviceKeyKey, identity.deviceKey);
    return identity;
  }
}
