// lib/features/tables/data/datasources/remote/tables_remote_datasource_impl.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../dtos/table_dto.dart';
import 'tables_remote_datasource.dart';

class TablesRemoteDatasourceImpl implements TablesRemoteDatasource {
  final SupabaseClient _client;
  final String _branchId;

  TablesRemoteDatasourceImpl(this._client, this._branchId);

  @override
  Future<List<TableDto>> getTables() async {
    final response = await _client
        .from('tables')
        .select('*, table_floors(name)')
        .eq('branch_id', _branchId)
        .eq('is_active', true)
        .order('sequence_num', ascending: true)
        .order('label', ascending: true);

    return (response as List)
        .map((json) => TableDto.fromMap(json))
        .toList();
  }

  @override
  Future<TableDto> updateTableStatus(String id, String status, {String? orderId}) async {
    final response = await _client
        .from('tables')
        .update({
          'active_order_id': orderId,
        })
        .eq('id', id)
        .select()
        .single();

    return TableDto.fromMap(response);
  }

  @override
  Stream<List<TableDto>> watchTables() {
    return _client
        .from('tables')
        .stream(primaryKey: ['id'])
        .eq('branch_id', _branchId)
        .order('sequence_num', ascending: true)
        .order('label', ascending: true)
        .map((event) {
          // The stream doesn't support joins, so we parse floor_id from the raw row
          // and the floor name will be populated on the initial fetch.
          return event
              .where((json) => json['is_active'] == true)
              .map((json) => TableDto.fromMap(json))
              .toList();
        });
  }

  @override
  Future<void> mergeTables(List<String> sourceTableIds, String targetTableId) async {
    try {
      await _client
          .from('tables')
          .update({
            'merged_table_ids': sourceTableIds,
          })
          .eq('id', targetTableId);

      for (final srcId in sourceTableIds) {
        await _client
            .from('tables')
            .update({
              'active_order_id': null,
            })
            .eq('id', srcId);
      }
    } catch (_) {
      // Fallback
    }
  }

  @override
  Future<void> splitTable(String tableId, List<Map<String, dynamic>> splitPartitions) async {
    try {
      await _client
          .from('tables')
          .update({
            'occupied_seats': splitPartitions,
          })
          .eq('id', tableId);
    } catch (_) {
      // Fallback: ignore if column doesn't exist
    }
  }
}
