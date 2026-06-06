import '../entities/connection_profile.dart';

abstract interface class ConnectionProfileRepository {
  Future<List<ConnectionProfile>> loadAll();

  Future<ConnectionProfile> load();

  Future<void> save(ConnectionProfile profile);

  Future<void> saveAll(List<ConnectionProfile> profiles);

  ConnectionProfile createProfile();
}
