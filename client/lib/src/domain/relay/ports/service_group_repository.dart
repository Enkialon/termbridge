import '../entities/service_group.dart';

abstract interface class ServiceGroupRepository {
  Future<List<ServiceGroup>> loadAll();

  Future<void> save(ServiceGroup group);

  Future<void> saveAll(List<ServiceGroup> groups);
}
