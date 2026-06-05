import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ServiceNode {
  const ServiceNode({
    required this.id,
    required this.name,
    required this.relayHost,
    required this.relayPort,
    required this.token,
    required this.useTls,
    required this.allowBadCertificate,
  });

  final String id;
  final String name;
  final String relayHost;
  final int relayPort;
  final String token;
  final bool useTls;
  final bool allowBadCertificate;

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'relayHost': relayHost,
      'relayPort': relayPort,
      'token': token,
      'useTls': useTls,
      'allowBadCertificate': allowBadCertificate,
    };
  }

  factory ServiceNode.fromJson(Map<String, Object?> json) {
    return ServiceNode(
      id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      relayHost: json['relayHost'] as String? ?? '',
      relayPort: json['relayPort'] as int? ?? 8080,
      token: json['token'] as String? ?? '',
      useTls: json['useTls'] as bool? ?? false,
      allowBadCertificate: json['allowBadCertificate'] as bool? ?? false,
    );
  }
}

class ServiceGroup {
  const ServiceGroup({
    required this.id,
    required this.name,
    required this.nodes,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final List<ServiceNode> nodes;
  final DateTime updatedAt;

  ServiceGroup copyWith({
    String? id,
    String? name,
    List<ServiceNode>? nodes,
    DateTime? updatedAt,
  }) {
    return ServiceGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      nodes: nodes ?? this.nodes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'name': name,
      'nodes': nodes.map((node) => node.toJson()).toList(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory ServiceGroup.fromJson(Map<String, Object?> json) {
    return ServiceGroup(
      id: json['id'] as String? ?? 'default',
      name: json['name'] as String? ?? '',
      nodes: (json['nodes'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ServiceNode.fromJson)
          .toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ServiceGroupStore {
  static const _groups = 'serviceGroups.v1';
  static const _legacyRelays = 'relayProfiles.v1';

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

    final legacy = prefs.getString(_legacyRelays);
    if (legacy == null) return [];

    final relays = jsonDecode(legacy) as List<dynamic>;
    final groups = relays.whereType<Map<String, dynamic>>().map((json) {
      final host = json['relayHost'] as String? ?? '';
      final port = json['relayPort'] as int? ?? 8080;
      return ServiceGroup(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: json['name'] as String? ?? '$host:$port',
        nodes: [
          ServiceNode(
            id: 'node-${json['id'] ?? host}',
            name: json['name'] as String? ?? '$host:$port',
            relayHost: host,
            relayPort: port,
            token: json['token'] as String? ?? '',
            useTls: json['useTls'] as bool? ?? false,
            allowBadCertificate: json['allowBadCertificate'] as bool? ?? false,
          ),
        ],
        updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
    }).toList();
    await saveAll(groups);
    return groups;
  }

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

  Future<void> saveAll(List<ServiceGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _groups,
      jsonEncode(groups.map((group) => group.toJson()).toList()),
    );
  }
}
