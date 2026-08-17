import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_service.dart';

class PlayerPreferences {
  const PlayerPreferences({
    required this.parentalEnabled,
    required this.autoplay,
    required this.quality,
  });

  final bool parentalEnabled;
  final bool autoplay;
  final String quality;
}

class PlayerPreferencesService {
  static const _parentalEnabled = 'parental_enabled';
  static const _pinHash = 'parental_pin_hash';
  static const _autoplay = 'autoplay';
  static const _quality = 'player_quality';
  static const _favorites = 'favorites';
  static const _recent = 'recent_items';
  static const _progressPrefix = 'progress_';

  Future<PlayerPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PlayerPreferences(
      parentalEnabled: prefs.getBool(_parentalEnabled) ?? false,
      autoplay: prefs.getBool(_autoplay) ?? true,
      quality: prefs.getString(_quality) ?? 'Auto',
    );
  }

  Future<void> setAutoplay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoplay, value);
  }

  Future<void> setQuality(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_quality, value);
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinHash, _hash(pin));
    await prefs.setBool(_parentalEnabled, true);
  }

  Future<void> disableParental() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_parentalEnabled, false);
  }

  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_pinHash);
    return stored != null && stored == _hash(pin);
  }


  Future<String> _profilePrefix() async {
    final id = await ProfileService().activeId();
    return id == null || id.isEmpty ? 'default' : id;
  }

  Future<Set<String>> favorites() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    return (prefs.getStringList('${_favorites}_$profile') ?? const <String>[]).toSet();
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    final key = '${_favorites}_$profile';
    final values = (prefs.getStringList(key) ?? <String>[]).toSet();
    values.contains(id) ? values.remove(id) : values.add(id);
    await prefs.setStringList(key, values.toList());
  }


  Future<List<String>> recentIds() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    return prefs.getStringList('${_recent}_$profile') ?? const <String>[];
  }

  Future<void> addRecent(String id, {int limit = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    final key = '${_recent}_$profile';
    final values = (prefs.getStringList(key) ?? <String>[])
        .where((e) => e != id)
        .toList();
    values.insert(0, id);
    if (values.length > limit) values.removeRange(limit, values.length);
    await prefs.setStringList(key, values);
  }

  Future<Map<String, Duration>> allProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    final prefix = '${_progressPrefix}${profile}_';
    final result = <String, Duration>{};
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(prefix)) continue;
      final ms = prefs.getInt(key);
      if (ms == null || ms <= 0) continue;
      result[key.substring(prefix.length)] = Duration(milliseconds: ms);
    }
    return result;
  }

  Future<Duration?> loadProgress(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    final ms = prefs.getInt('${_progressPrefix}${profile}_$id');
    return ms == null ? null : Duration(milliseconds: ms);
  }

  Future<void> saveProgress(String id, Duration position) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await _profilePrefix();
    await prefs.setInt(
      '${_progressPrefix}${profile}_$id',
      position.inMilliseconds,
    );
  }

  String _hash(String pin) => sha256.convert(utf8.encode('ZENQIVO::$pin')).toString();
}
