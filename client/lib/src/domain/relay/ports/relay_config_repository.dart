import '../entities/relay_config.dart';

abstract interface class RelayConfigRepository {
  Future<List<RelayConfig>> loadAll();

  Future<void> save(RelayConfig relayConfig);

  Future<void> saveAll(List<RelayConfig> relayConfigs);

  Future<void> delete(String id);
}
