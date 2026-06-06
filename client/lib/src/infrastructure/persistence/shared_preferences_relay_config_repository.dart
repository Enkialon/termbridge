import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/relay/entities/relay_config.dart';
import '../../domain/relay/ports/relay_config_repository.dart';

class SharedPreferencesRelayConfigRepository
    implements RelayConfigRepository {
  static const _relayConfigs = 'relayConfigs.v1';

  @override
  Future<List<RelayConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_relayConfigs);
    if (encoded != null) {
      final values = jsonDecode(encoded) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(RelayConfig.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return [];
  }

  @override
  Future<void> save(RelayConfig relayConfig) async {
    final relayConfigs = await loadAll();
    final saved = relayConfig.copyWith(updatedAt: DateTime.now());
    final index = relayConfigs.indexWhere((value) => value.id == saved.id);
    if (index == -1) {
      relayConfigs.insert(0, saved);
    } else {
      relayConfigs[index] = saved;
    }
    await saveAll(relayConfigs);
  }

  @override
  Future<void> saveAll(List<RelayConfig> relayConfigs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _relayConfigs,
      jsonEncode(
        relayConfigs.map((relayConfig) => relayConfig.toJson()).toList(),
      ),
    );
  }
}
