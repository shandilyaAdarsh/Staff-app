import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/session_service.dart';

// Will be overridden in the root widget
final sessionServiceProvider = Provider<SessionService>((ref) {
  throw UnimplementedError('Override sessionServiceProvider in ProviderScope');
});
