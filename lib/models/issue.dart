import 'json.dart';

class IssueToolRef {
  const IssueToolRef({required this.id, required this.toolCode, required this.name, this.uom = 'NOS'});

  final int id;
  final String toolCode;
  final String name;
  final String uom;

  factory IssueToolRef.fromJson(Json j) => IssueToolRef(
        id: asInt(j['id']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        uom: str(j['uom'], 'NOS'),
      );
}

class IssueEmployeeRef {
  const IssueEmployeeRef({required this.id, required this.name, this.code});

  final int id;
  final String name;
  final String? code;

  factory IssueEmployeeRef.fromJson(Json j) => IssueEmployeeRef(
        id: asInt(j['id']),
        name: str(j['name']),
        code: strOrNull(j['code']),
      );

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class ReturnRecord {
  const ReturnRecord({
    required this.id,
    required this.qty,
    this.returnDate,
    this.condition = 'GOOD',
    this.remarks,
    this.receivedByName,
  });

  final int id;
  final int qty;
  final DateTime? returnDate;
  final String condition;
  final String? remarks;
  final String? receivedByName;

  factory ReturnRecord.fromJson(Json j) => ReturnRecord(
        id: asInt(j['id']),
        qty: asInt(j['qty']),
        returnDate: asDate(j['returnDate']),
        condition: str(j['condition'], 'GOOD'),
        remarks: strOrNull(j['remarks']),
        receivedByName: strOrNull(j['receivedByName']),
      );
}

/// One issue record — who holds what, since when, and until when.
class ToolIssue {
  const ToolIssue({
    required this.id,
    required this.issueNo,
    required this.tool,
    required this.employee,
    required this.qtyIssued,
    this.qtyReturned = 0,
    this.qtyOutstanding = 0,
    this.department,
    this.location,
    this.issueDate,
    this.dueDate,
    this.returnedOn,
    this.status = 'ISSUED',
    this.isOverdue = false,
    this.daysOverdue = 0,
    this.purpose,
    this.workOrderNo,
    this.issuedByName,
    this.receivedBackByName,
    this.remarks,
    this.returns = const [],
    this.maintenanceRecordNo,
  });

  final int id;
  final String issueNo;
  final IssueToolRef tool;
  final IssueEmployeeRef employee;
  final String? department;
  final String? location;
  final int qtyIssued;
  final int qtyReturned;
  final int qtyOutstanding;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final DateTime? returnedOn;
  final String status;
  final bool isOverdue;
  final int daysOverdue;
  final String? purpose;
  final String? workOrderNo;
  final String? issuedByName;
  final String? receivedBackByName;
  final String? remarks;
  final List<ReturnRecord> returns;

  /// Set when a return raised a damage/loss record.
  final String? maintenanceRecordNo;

  bool get isClosed => status == 'RETURNED';

  /// Live status: the API stamps OVERDUE nightly, but a record can cross its
  /// due date mid-shift.
  String get effectiveStatus => !isClosed && isOverdue ? 'OVERDUE' : status;

  factory ToolIssue.fromJson(Json j) => ToolIssue(
        id: asInt(j['id']),
        issueNo: str(j['issueNo']),
        tool: IssueToolRef.fromJson(asMap(j['tool'])),
        employee: IssueEmployeeRef.fromJson(asMap(j['employee'])),
        department: strOrNull(j['department']),
        location: strOrNull(j['location']),
        qtyIssued: asInt(j['qtyIssued']),
        qtyReturned: asInt(j['qtyReturned']),
        qtyOutstanding: asInt(j['qtyOutstanding']),
        issueDate: asDate(j['issueDate']),
        dueDate: asDate(j['dueDate']),
        returnedOn: asDate(j['returnedOn']),
        status: str(j['status'], 'ISSUED'),
        isOverdue: asBool(j['isOverdue']),
        daysOverdue: asInt(j['daysOverdue']),
        purpose: strOrNull(j['purpose']),
        workOrderNo: strOrNull(j['workOrderNo']),
        issuedByName: strOrNull(j['issuedByName']),
        receivedBackByName: strOrNull(j['receivedBackByName']),
        remarks: strOrNull(j['remarks']),
        returns: asList(j['returns'], ReturnRecord.fromJson),
        maintenanceRecordNo: strOrNull(j['maintenanceRecordNo']),
      );
}

class IssueSummary {
  const IssueSummary({
    this.openCount = 0,
    this.qtyOutstanding = 0,
    this.overdueCount = 0,
    this.returnedCount = 0,
    this.issuedToday = 0,
    this.totalCount = 0,
  });

  final int openCount;
  final int qtyOutstanding;
  final int overdueCount;
  final int returnedCount;
  final int issuedToday;
  final int totalCount;

  factory IssueSummary.fromJson(Json j) => IssueSummary(
        openCount: asInt(j['openCount']),
        qtyOutstanding: asInt(j['qtyOutstanding']),
        overdueCount: asInt(j['overdueCount']),
        returnedCount: asInt(j['returnedCount']),
        issuedToday: asInt(j['issuedToday']),
        totalCount: asInt(j['totalCount']),
      );
}

class Reservation {
  const Reservation({
    required this.id,
    required this.reservationNo,
    required this.tool,
    required this.qty,
    this.employeeId,
    this.employeeName,
    this.locationId,
    this.locationName,
    this.fromDate,
    this.toDate,
    this.status = 'ACTIVE',
    this.purpose,
  });

  final int id;
  final String reservationNo;
  final IssueToolRef tool;
  final int? employeeId;
  final String? employeeName;
  final int? locationId;
  final String? locationName;
  final int qty;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String status;
  final String? purpose;

  factory Reservation.fromJson(Json j) => Reservation(
        id: asInt(j['id']),
        reservationNo: str(j['reservationNo']),
        tool: IssueToolRef.fromJson(asMap(j['tool'])),
        employeeId: asIntOrNull(j['employeeId']),
        employeeName: strOrNull(j['employeeName']),
        locationId: asIntOrNull(j['locationId']),
        locationName: strOrNull(j['locationName']),
        qty: asInt(j['qty']),
        fromDate: asDate(j['fromDate']),
        toDate: asDate(j['toDate']),
        status: str(j['status'], 'ACTIVE'),
        purpose: strOrNull(j['purpose']),
      );

  bool get isActive => status == 'ACTIVE';

  /// Days until the hold lapses; negative once the window has passed. The
  /// nightly job releases an expired reservation, so this can read negative for
  /// a few hours before the status catches up.
  int? get daysRemaining {
    if (toDate == null) return null;
    final today = DateTime.now();
    return DateTime(toDate!.year, toDate!.month, toDate!.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
  }

  bool get isLapsing => isActive && (daysRemaining ?? 99) <= 0;
}

/// Payload for POST /issues.
class IssueRequest {
  const IssueRequest({
    required this.toolId,
    required this.employeeId,
    required this.qty,
    this.departmentId,
    this.locationId,
    this.issueDate,
    this.dueDate,
    this.purpose,
    this.workOrderNo,
    this.remarks,
    this.reservationId,
  });

  final int toolId;
  final int employeeId;
  final int qty;
  final int? departmentId;
  final int? locationId;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String? purpose;
  final String? workOrderNo;
  final String? remarks;
  final int? reservationId;

  Json toJson() => {
        'toolId': toolId,
        'employeeId': employeeId,
        'qty': qty,
        if (departmentId != null) 'departmentId': departmentId,
        if (locationId != null) 'locationId': locationId,
        if (issueDate != null) 'issueDate': _d(issueDate!),
        if (dueDate != null) 'dueDate': _d(dueDate!),
        if (purpose?.isNotEmpty == true) 'purpose': purpose,
        if (workOrderNo?.isNotEmpty == true) 'workOrderNo': workOrderNo,
        if (remarks?.isNotEmpty == true) 'remarks': remarks,
        if (reservationId != null) 'reservationId': reservationId,
      };
}

String _d(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
