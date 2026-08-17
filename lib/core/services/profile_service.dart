import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/profile.dart';

class ProfileService {
  static const _profilesKey = 'zenqivo_profiles';
  static const _activeKey = 'zenqivo_active_profile';

  Future<List<ZenqivoProfile>> list() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_profilesKey) ?? const [];
    final values = <ZenqivoProfile>[];
    for (final item in raw) {
      try {
        values.add(
          ZenqivoProfile.fromJson(
            Map<String, dynamic>.from(jsonDecode(item) as Map),
          ),
        );
      } catch (_) {}
    }
    if (values.isEmpty) {
      final first = ZenqivoProfile(
        id: _id(),
        name: 'Main',
        avatarIndex: 0,
        createdAt: DateTime.now(),
      );
      await save([first]);
      return [first];
    }
    return values;
  }

  Future<void> save(List<ZenqivoProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _profilesKey,
      profiles.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<ZenqivoProfile> add(String name, int avatarIndex) async {
    final profiles = await list();
    if (profiles.length >= 6) {
      throw StateError('profile_limit');
    }
    final profile = ZenqivoProfile(
      id: _id(),
      name: name.trim(),
      avatarIndex: avatarIndex,
      createdAt: DateTime.now(),
    );
    await save([...profiles, profile]);
    return profile;
  }


  Future<ZenqivoProfile> update(
    String id, {
    required String name,
    required int avatarIndex,
  }) async {
    final profiles = await list();
    final updated = <ZenqivoProfile>[];
    ZenqivoProfile? result;
    for (final profile in profiles) {
      if (profile.id == id) {
        result = ZenqivoProfile(
          id: profile.id,
          name: name.trim(),
          avatarIndex: avatarIndex,
          createdAt: profile.createdAt,
        );
        updated.add(result);
      } else {
        updated.add(profile);
      }
    }
    if (result == null) throw StateError('profile_not_found');
    await save(updated);
    return result;
  }

  Future<void> remove(String id) async {
    final profiles = await list();
    if (profiles.length <= 1) return;
    await save(profiles.where((e) => e.id != id).toList());
    final active = await activeId();
    if (active == id) {
      final remaining = await list();
      await setActive(remaining.first.id);
    }
  }

  Future<void> setActive(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, id);
  }

  Future<String?> activeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeKey);
  }

  String _id() {
    final rand = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final tail = List.generate(6, (_) => rand.nextInt(36).toRadixString(36)).join();
    return 'profile-$now-$tail';
  }
}
