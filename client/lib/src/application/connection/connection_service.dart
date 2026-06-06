import '../../domain/connection/entities/connection_profile.dart';
import '../../domain/connection/ports/connection_profile_repository.dart';

class ConnectionService {
  const ConnectionService({
    required ConnectionProfileRepository profiles,
  }) : _profiles = profiles;

  final ConnectionProfileRepository _profiles;

  Future<List<ConnectionProfile>> loadAll() => _profiles.loadAll();

  ConnectionProfile createProfile() => _profiles.createProfile();

  Future<ConnectionProfile> save(ConnectionProfile profile) async {
    final saved = profile.ensureSessionId();
    await _profiles.save(saved);
    return saved;
  }

  Future<void> delete(ConnectionProfile profile) async {
    final profiles = await _profiles.loadAll();
    profiles.removeWhere((value) => value.id == profile.id);
    await _profiles.saveAll(profiles);
  }
}
