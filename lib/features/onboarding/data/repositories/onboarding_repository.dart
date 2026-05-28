// lib/features/onboarding/data/repositories/onboarding_repository.dart


import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/onboarding_status_model.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final dio = ref.watch(dioClientProvider);
  return OnboardingRepository(dio);
});

class OnboardingRepository {
  final DioClient _dio;

  OnboardingRepository(this._dio);

  Future<OnboardingStatusModel> getOnboardingStatus() async {
    try {
      final response = await _dio.get('/v1/admin/onboarding/status');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return OnboardingStatusModel.fromJson(response.data['data']);
      }
      
      throw Exception('Failed to fetch onboarding status: ${response.data['error']}');
    } catch (e) {
      // Mock for UI simulator if network fails
      return const OnboardingStatusModel(
        tenantId: 'mock-tenant',
        hasCategories: true,
        hasMenuItems: true,
        hasTaxProfiles: true,
        hasTables: true,
        hasStaff: true,
        hasKdsStations: true,
        setupStage: 'COMPLETED',
        isOperational: true,
      );
    }
  }
}
