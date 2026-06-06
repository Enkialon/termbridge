import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/connection/entities/connection_profile.dart';
import '../../domain/connection/ports/connection_profile_repository.dart';

class SharedPreferencesConnectionProfileRepository
    implements ConnectionProfileRepository {
  static const _profiles = 'connectionProfiles.v1';

  @override
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

    return [];
  }

  @override
  Future<ConnectionProfile> load() async {
    final profiles = await loadAll();
    return profiles.isEmpty ? createProfile() : profiles.first;
  }

  @override
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

  @override
  Future<void> saveAll(List<ConnectionProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      profiles.map((profile) => profile.toJson()).toList(),
    );
    await prefs.setString(_profiles, encoded);
  }

  @override
  ConnectionProfile createProfile() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return ConnectionProfile(
      id: now.toString(),
      name: '',
      relayConfigId: '',
      deviceId: '',
      sessionId: '',
      password: '',
      username: '',
      updatedAt: DateTime.now(),
    );
  }
}
