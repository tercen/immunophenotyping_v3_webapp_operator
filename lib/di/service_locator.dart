import 'package:get_it/get_it.dart';
import '../domain/services/data_service.dart';
import '../implementations/services/mock_data_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Register services. Called once from main().
///
/// Mock mode: registers MockDataService.
/// Real mode: registers Tercen context + real data service.
///
/// Phase 3 adds:
///   import 'package:sci_tercen_client/sci_client_service_factory.dart';
///   setupServiceLocator(useMocks: false, factory: factory, taskId: taskId);
///   // where factory = await createServiceFactoryForWebApp()
void setupServiceLocator({
  bool useMocks = true,
  // Phase 3: uncomment to accept factory + taskId
  // ServiceFactory? factory,
  // String? taskId,
}) {
  if (serviceLocator.isRegistered<DataService>()) return;

  if (useMocks) {
    serviceLocator.registerLazySingleton<DataService>(
      () => MockDataService(),
    );
  }
  // Phase 3: add else branch:
  // else {
  //   serviceLocator.registerLazySingleton<DataService>(
  //     () => TercenDataService(factory!, taskId!),
  //   );
  // }
}
