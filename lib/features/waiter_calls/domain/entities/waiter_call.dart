// lib/features/waiter_calls/domain/entities/waiter_call.dart

enum CallType {
  service,
  billRequest,
  assistance,
  issueReport,
}

enum CallStatus {
  pending,
  acknowledged,
  resolved,
  escalated,
}

class WaiterCall {
  final String id;
  final String tableId;
  final String tableLabel;
  final CallType type;
  final CallStatus status;
  final String? customerNote;
  final DateTime timestamp;
  final String? waiterId;
  final String? waiterName;
  final bool isVip;
  final int versionNum;

  const WaiterCall({
    required this.id,
    required this.tableId,
    required this.tableLabel,
    required this.type,
    required this.status,
    this.customerNote,
    required this.timestamp,
    this.waiterId,
    this.waiterName,
    this.isVip = false,
    this.versionNum = 1,
  });

  bool get isUrgent {
    final elapsedSeconds = DateTime.now().difference(timestamp).inSeconds;
    if (type == CallType.issueReport) return true;
    if (isVip && elapsedSeconds > 45) return true;
    return elapsedSeconds > 120;
  }

  double calculatePriorityScore(bool isRushHour) {
    final elapsedSeconds = DateTime.now().difference(timestamp).inSeconds;
    double timeWeight = isRushHour ? 1.5 : 1.0;
    
    double severityScore = 10.0;
    switch (type) {
      case CallType.service:
      case CallType.assistance:
        severityScore = 10.0;
        break;
      case CallType.billRequest:
        severityScore = 20.0;
        break;
      case CallType.issueReport:
        severityScore = 30.0;
        break;
    }

    double vipBuffer = isVip ? 25.0 : 0.0;

    return (elapsedSeconds * timeWeight) + severityScore + vipBuffer;
  }

  WaiterCall copyWith({
    String? id,
    String? tableId,
    String? tableLabel,
    CallType? type,
    CallStatus? status,
    String? customerNote,
    DateTime? timestamp,
    String? waiterId,
    String? waiterName,
    bool? isVip,
    int? versionNum,
  }) {
    return WaiterCall(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      tableLabel: tableLabel ?? this.tableLabel,
      type: type ?? this.type,
      status: status ?? this.status,
      customerNote: customerNote ?? this.customerNote,
      timestamp: timestamp ?? this.timestamp,
      waiterId: waiterId ?? this.waiterId,
      waiterName: waiterName ?? this.waiterName,
      isVip: isVip ?? this.isVip,
      versionNum: versionNum ?? this.versionNum,
    );
  }
}
