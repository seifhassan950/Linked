import 'api_client.dart';
import 'auth_service.dart';

final ApiClient r2vApiClient = ApiClient();
final AuthService r2vAuth = AuthService(r2vApiClient);
