// lib/main_prod.dart
import 'bootstrap/bootstrap.dart';
import 'core/config/environment.dart';

void main() {
  bootstrap(
    environment: Environment.prod,
    apiBaseUrl: 'https://api.orderlyy.com/v1',
    websocketUrl: 'wss://api.orderlyy.com/v1/realtime',
    enableSentry: true,
  );
}
