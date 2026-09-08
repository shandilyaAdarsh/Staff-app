// lib/features/tables/data/datasources/remote/tables_remote_datasource.dart
import '../../dtos/table_dto.dart';

abstract class TablesRemoteDatasource {
  Future<List<TableDto>> getTables();
  Future<TableDto> updateTableStatus(String id, String status, {String? orderId});
  Stream<List<TableDto>> watchTables();
  Future<void> mergeTables(List<String> sourceTableIds, String targetTableId);

}
