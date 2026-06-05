import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../controller/models/connection_profile.dart';

class ProfileStore {
  static const _profiles = 'profiles.v2';
  static const _relayHost = 'relayHost';
  static const _relayPort = 'relayPort';
  static const _deviceId = 'deviceId';
  static const _sessionId = 'sessionId';
  static const _token = 'token';
  static const _username = 'username';
  static const _useTls = 'useTls';
  static const _allowBadCertificate = 'allowBadCertificate';

  Future<List<ConnectionProfile>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_profiles);
    if (encoded != null) {
      final values = jsonDecode(encoded) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(ConnectionProfile.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    if (_hasLegacyProfile(prefs)) {
      final migrated = _loadLegacy(prefs);
      await saveAll([migrated]);
      return [migrated];
    }

    return [];
  }

  Future<ConnectionProfile> load() async {
    final profiles = await loadAll();
    return profiles.isEmpty ? createProfile() : profiles.first;
  }

  Future<void> save(ConnectionProfile profile) async {
    final profiles = await loadAll();
    final saved = profile.copyWith(updatedAt: DateTime.now());
    final index = profiles.indexWhere((value) => value.id == profile.id);
    if (index == -1) {
      profiles.insert(0, saved);
    } else {
      profiles[index] = saved;
    }
    await saveAll(profiles);
  }

  Future<void> saveAll(List<ConnectionProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    await prefs.setString(_profiles, encoded);
  }

  ConnectionProfile createProfile() {
    return ConnectionProfile.defaults.copyWith(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      updatedAt: DateTime.now(),
    );
  }

  bool _hasLegacyProfile(SharedPreferences prefs) {
    return prefs.containsKey(_relayHost) ||
        prefs.containsKey(_relayPort) ||
        prefs.containsKey(_deviceId) ||
        prefs.containsKey(_sessionId) ||
        prefs.containsKey(_token) ||
        prefs.containsKey(_username);
  }

  ConnectionProfile _loadLegacy(SharedPreferences prefs) {
    final defaults = ConnectionProfile.defaults;
    return defaults.copyWith(
      relayHost: prefs.getString(_relayHost) ?? defaults.relayHost,
      relayPort: prefs.getInt(_relayPort) ?? defaults.relayPort,
      deviceId: prefs.getString(_deviceId) ?? defaults.deviceId,
      sessionId: prefs.getString(_sessionId) ?? defaults.sessionId,
      token: prefs.getString(_token) ?? defaults.token,
      username: prefs.getString(_username) ?? defaults.username,
      useTls: prefs.getBool(_useTls) ?? defaults.useTls,
      allowBadCertificate:
          prefs.getBool(_allowBadCertificate) ?? defaults.allowBadCertificate,
      updatedAt: DateTime.now(),
    );
  }
}
