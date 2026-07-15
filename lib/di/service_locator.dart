import 'package:get_it/get_it.dart';
import 'package:sci_tercen_client/sci_client_service_factory.dart';
import '../domain/services/data_service.dart';
import '../implementations/services/mock_data_service.dart';
import '../implementations/services/tercen_workflow_service.dart';

final GetIt serviceLocator = GetIt.instance;

/// Register services. Called once from main().
///
/// Mock mode: registers MockDataService.
/// Real mode: registers ServiceFactory + TercenWorkflowService.
void setupServiceLocator({
  bool useMocks = true,
  ServiceFactory? factory,
  String? projectId,
  DataService? sarnoService,
}) {
  if (serviceLocator.isRegistered<DataService>()) return;

  // Register projectId for provider access
  serviceLocator.registerSingleton<String>(
    projectId ?? '',
    instanceName: 'projectId',
  );

  if (sarnoService != null) {
    // Sarno backend (app served by a Sarno board — meta tags present).
    serviceLocator.registerSingleton<DataService>(sarnoService);
  } else if (useMocks) {
    serviceLocator.registerLazySingleton<DataService>(
      () => MockDataService(),
    );
  } else {
    serviceLocator.registerSingleton<ServiceFactory>(factory!);
    serviceLocator.registerLazySingleton<DataService>(
      () => TercenWorkflowService(factory, projectId ?? ''),
    );
  }
}
