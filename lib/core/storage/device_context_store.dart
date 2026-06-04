import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../bootstrap/bootstrap.dart';

final deviceContextStoreProvider = Provider<DeviceContextStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DeviceContextStore(prefs);
});

class DeviceContextStore {
  static const _kTenantIdKey = 'device_tenant_id';
  static const _kBranchIdKey = 'device_branch_id';
  static const _kBranchNameKey = 'device_branch_name';

  final SharedPreferences _prefs;

  DeviceContextStore(this._prefs);

  Future<void> saveContext({
    required String tenantId,
    required String branchId,
    required String branchName,
  }) async {
    await _prefs.setString(_kTenantIdKey, tenantId);
    await _prefs.setString(_kBranchIdKey, branchId);
    await _prefs.setString(_kBranchNameKey, branchName);
  }

  String? get tenantId => _prefs.getString(_kTenantIdKey);
  String? get branchId => _prefs.getString(_kBranchIdKey);
  String? get branchName => _prefs.getString(_kBranchNameKey);

  bool get hasContext => tenantId != null && branchId != null;

  Future<void> clearContext() async {
    await _prefs.remove(_kTenantIdKey);
    await _prefs.remove(_kBranchIdKey);
    await _prefs.remove(_kBranchNameKey);
  }
}
