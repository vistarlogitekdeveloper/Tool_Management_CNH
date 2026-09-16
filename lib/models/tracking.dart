import 'json.dart';

/// One zone card across the top of the Tool Tracking screen.
class TrackingZone {
  const TrackingZone({
    required this.shop,
    this.toolCount = 0,
    this.totalQty = 0,
    this.inUseQty = 0,
    this.availableQty = 0,
    this.repairQty = 0,
    this.utilisationPercent = 0,
  });

  final String shop;
  final int toolCount;
  final int totalQty;
  final int inUseQty;
  final int availableQty;
  final int repairQty;
  final int utilisationPercent;

  factory TrackingZone.fromJson(Json j) => TrackingZone(
        shop: str(j['shop']),
        toolCount: asInt(j['toolCount']),
        totalQty: asInt(j['totalQty']),
        inUseQty: asInt(j['inUseQty']),
        availableQty: asInt(j['availableQty']),
        repairQty: asInt(j['repairQty']),
        utilisationPercent: asInt(j['utilisationPercent']),
      );
}

class TrackedLocationRef {
  const TrackedLocationRef({required this.id, required this.name, this.shop, this.station});

  final int id;
  final String name;
  final String? shop;
  final String? station;

  factory TrackedLocationRef.fromJson(Json j) => TrackedLocationRef(
        id: asInt(j['id']),
        name: str(j['name']),
        shop: strOrNull(j['shop']),
        station: strOrNull(j['station']),
      );
}

/// A row on the live locations table.
class TrackedTool {
  const TrackedTool({
    required this.toolId,
    required this.toolCode,
    required this.name,
    this.categoryName,
    this.categoryColour,
    this.homeLocation,
    this.totalQty = 0,
    this.availableQty = 0,
    this.issuedQty = 0,
    this.repairQty = 0,
    this.reservedQty = 0,
    this.heldBy,
    this.heldAt,
    this.hasOverdue = false,
    this.status = 'IN_STORE',
    this.lastMovedAt,
  });

  final int toolId;
  final String toolCode;
  final String name;
  final String? categoryName;
  final String? categoryColour;
  final TrackedLocationRef? homeLocation;
  final int totalQty;
  final int availableQty;
  final int issuedQty;
  final int repairQty;
  final int reservedQty;
  final String? heldBy;
  final String? heldAt;
  final bool hasOverdue;
  final String status;
  final DateTime? lastMovedAt;

  String get holderLabel => heldBy?.isNotEmpty == true ? heldBy! : '— In Store —';

  factory TrackedTool.fromJson(Json j) => TrackedTool(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        categoryName: strOrNull(j['categoryName']),
        categoryColour: strOrNull(j['categoryColour']),
        homeLocation: asMapOrNull(j['homeLocation']) == null
            ? null
            : TrackedLocationRef.fromJson(asMap(j['homeLocation'])),
        totalQty: asInt(j['totalQty']),
        availableQty: asInt(j['availableQty']),
        issuedQty: asInt(j['issuedQty']),
        repairQty: asInt(j['repairQty']),
        reservedQty: asInt(j['reservedQty']),
        heldBy: strOrNull(j['heldBy']),
        heldAt: strOrNull(j['heldAt']),
        hasOverdue: asBool(j['hasOverdue']),
        status: str(j['status'], 'IN_STORE'),
        lastMovedAt: asDate(j['lastMovedAt']),
      );
}

class ToolHolder {
  const ToolHolder({
    required this.issueNo,
    required this.employeeName,
    required this.qty,
    this.employeeCode,
    this.department,
    this.location,
    this.shop,
    this.issueDate,
    this.dueDate,
    this.isOverdue = false,
  });

  final String issueNo;
  final String employeeName;
  final String? employeeCode;
  final String? department;
  final String? location;
  final String? shop;
  final int qty;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final bool isOverdue;

  factory ToolHolder.fromJson(Json j) => ToolHolder(
        issueNo: str(j['issueNo']),
        employeeName: str(j['employeeName']),
        employeeCode: strOrNull(j['employeeCode']),
        department: strOrNull(j['department']),
        location: strOrNull(j['location']),
        shop: strOrNull(j['shop']),
        qty: asInt(j['qty']),
        issueDate: asDate(j['issueDate']),
        dueDate: asDate(j['dueDate']),
        isOverdue: asBool(j['isOverdue']),
      );
}

/// Result of "Locate Tool" — where every unit of one tool is right now.
class ToolLocation {
  const ToolLocation({
    required this.toolId,
    required this.toolCode,
    required this.name,
    this.homeLocation,
    this.shop,
    this.inStore = 0,
    this.inUse = 0,
    this.inRepair = 0,
    this.reserved = 0,
    this.holders = const [],
    this.recentMovements = const [],
  });

  final int toolId;
  final String toolCode;
  final String name;
  final String? homeLocation;
  final String? shop;
  final int inStore;
  final int inUse;
  final int inRepair;
  final int reserved;
  final List<ToolHolder> holders;
  final List<TrackingMovement> recentMovements;

  factory ToolLocation.fromJson(Json j) => ToolLocation(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        homeLocation: strOrNull(j['homeLocation']),
        shop: strOrNull(j['shop']),
        inStore: asInt(j['inStore']),
        inUse: asInt(j['inUse']),
        inRepair: asInt(j['inRepair']),
        reserved: asInt(j['reserved']),
        holders: asList(j['holders'], ToolHolder.fromJson),
        recentMovements: asList(j['recentMovements'], TrackingMovement.fromJson),
      );
}

class TrackingMovement {
  const TrackingMovement({
    required this.type,
    required this.qty,
    this.from,
    this.to,
    this.employeeName,
    this.byUser,
    this.at,
  });

  final String type;
  final int qty;
  final String? from;
  final String? to;
  final String? employeeName;
  final String? byUser;
  final DateTime? at;

  factory TrackingMovement.fromJson(Json j) => TrackingMovement(
        type: str(j['type']),
        qty: asInt(j['qty']),
        from: strOrNull(j['from']),
        to: strOrNull(j['to']),
        employeeName: strOrNull(j['employeeName']),
        byUser: strOrNull(j['byUser']),
        at: asDate(j['at']),
      );
}

class ToolTransfer {
  const ToolTransfer({
    required this.id,
    required this.transferNo,
    required this.toolCode,
    this.toolName,
    this.qty = 1,
    this.from,
    this.to,
    this.transferDate,
    this.reason,
    this.status = 'COMPLETED',
    this.byUser,
  });

  final int id;
  final String transferNo;
  final String toolCode;
  final String? toolName;
  final int qty;
  final String? from;
  final String? to;
  final DateTime? transferDate;
  final String? reason;
  final String status;
  final String? byUser;

  factory ToolTransfer.fromJson(Json j) => ToolTransfer(
        id: asInt(j['id']),
        transferNo: str(j['transferNo']),
        toolCode: str(j['toolCode']),
        toolName: strOrNull(j['toolName']),
        qty: asInt(j['qty'], 1),
        from: strOrNull(j['from']),
        to: strOrNull(j['to']),
        transferDate: asDate(j['transferDate']),
        reason: strOrNull(j['reason']),
        status: str(j['status'], 'COMPLETED'),
        byUser: strOrNull(j['byUser']),
      );
}
