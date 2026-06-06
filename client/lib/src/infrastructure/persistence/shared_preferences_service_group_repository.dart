import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/relay/entities/service_group.dart';
import '../../domain/relay/ports/service_group_repository.dart';

class SharedPreferencesServiceGroupRepository
    implements ServiceGroupRepository {
  static const _groups = 'serviceGroups.v1';

  @override
  Future<List<ServiceGroup>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_groups);
    if (encoded != null) {
      final values = jsonDecode(encoded) as List<dynamic>;
      return values
          .whereType<Map<String, dynamic>>()
          .map(ServiceGroup.fromJson)
          .toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    }

    return [];
  }

  @override
  Future<void> save(ServiceGroup group) async {
    final groups = await loadAll();
    final saved = group.copyWith(updatedAt: DateTime.now());
    final index = groups.indexWhere((value) => value.id == saved.id);
    if (index == -1) {
      groups.insert(0, saved);
    } else {
      groups[index] = saved;
    }
    await saveAll(groups);
  }

  @override
  Future<void> saveAll(List<ServiceGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _groups,
      jsonEncode(groups.map((group) => group.toJson()).toList()),
    );
  }
}
