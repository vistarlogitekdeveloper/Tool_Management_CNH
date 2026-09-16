import 'json.dart';
import 'issue.dart' show IssueToolRef;

/// A repair, scrap, damage or loss record.
class MaintenanceRecord {
  const MaintenanceRecord({
    required this.id,
    required this.recordNo,
    required this.tool,
    required this.type,
    required this.qty,
    this.recordDate,
    this.vendorId,
    this.vendorName,
    this.cost = 0,
    this.reason = '',
    this.reportedByName,
    this.issueNo,
    this.approvalStatus = 'PENDING',
    this.approvedByName,
    this.approvedAt,
    this.approvalRemarks,
    this.expectedReturnDate,
    this.completedDate,
    this.completionStatus,
    this.attachmentId,
    this.remarks,
    this.createdByName,
    this.createdAt,
  });

  final int id;
  final String recordNo;
  final IssueToolRef tool;
  final String type;
  final int qty;
  final DateTime? recordDate;
  final int? vendorId;
  final String? vendorName;
  final double cost;
  final String reason;
  final String? reportedByName;
  final String? issueNo;
  final String approvalStatus;
  final String? approvedByName;
  final DateTime? approvedAt;
  final String? approvalRemarks;
  final DateTime? expectedReturnDate;
  final DateTime? completedDate;
  final String? completionStatus;
  final String? attachmentId;
  final String? remarks;
  final String? createdByName;
  final DateTime? createdAt;

  bool get isPending => approvalStatus == 'PENDING';
  bool get isApproved => approvalStatus == 'APPROVED';

  /// An approved repair that has not yet come back from the vendor.
  bool get isOpenRepair => type == 'REPAIR' && isApproved && completedDate == null;

  factory MaintenanceRecord.fromJson(Json j) => MaintenanceRecord(
        id: asInt(j['id']),
        recordNo: str(j['recordNo']),
        tool: IssueToolRef.fromJson(asMap(j['tool'])),
        type: str(j['type'], 'REPAIR'),
        qty: asInt(j['qty']),
        recordDate: asDate(j['recordDate']),
        vendorId: asIntOrNull(j['vendorId']),
        vendorName: strOrNull(j['vendorName']),
        cost: asDouble(j['cost']),
        reason: str(j['reason']),
        reportedByName: strOrNull(j['reportedByName']),
        issueNo: strOrNull(j['issueNo']),
        approvalStatus: str(j['approvalStatus'], 'PENDING'),
        approvedByName: strOrNull(j['approvedByName']),
        approvedAt: asDate(j['approvedAt']),
        approvalRemarks: strOrNull(j['approvalRemarks']),
        expectedReturnDate: asDate(j['expectedReturnDate']),
        completedDate: asDate(j['completedDate']),
        completionStatus: strOrNull(j['completionStatus']),
        attachmentId: strOrNull(j['attachmentId']),
        remarks: strOrNull(j['remarks']),
        createdByName: strOrNull(j['createdByName']),
        createdAt: asDate(j['createdAt']),
      );
}

class MaintenanceSummary {
  const MaintenanceSummary({
    this.inRepairQty = 0,
    this.scrappedQty = 0,
    this.damagedQty = 0,
    this.lostQty = 0,
    this.pendingApprovals = 0,
    this.openRepairs = 0,
    this.repairCostMtd = 0,
    this.repairCostYtd = 0,
  });

  final int inRepairQty;
  final int scrappedQty;
  final int damagedQty;
  final int lostQty;
  final int pendingApprovals;
  final int openRepairs;
  final double repairCostMtd;
  final double repairCostYtd;

  factory MaintenanceSummary.fromJson(Json j) => MaintenanceSummary(
        inRepairQty: asInt(j['inRepairQty']),
        scrappedQty: asInt(j['scrappedQty']),
        damagedQty: asInt(j['damagedQty']),
        lostQty: asInt(j['lostQty']),
        pendingApprovals: asInt(j['pendingApprovals']),
        openRepairs: asInt(j['openRepairs']),
        repairCostMtd: asDouble(j['repairCostMtd']),
        repairCostYtd: asDouble(j['repairCostYtd']),
      );
}

class VendorCost {
  const VendorCost({
    required this.vendorName,
    this.recordCount = 0,
    this.qty = 0,
    this.totalCost = 0,
    this.avgCost = 0,
  });

  final String vendorName;
  final int recordCount;
  final int qty;
  final double totalCost;
  final double avgCost;

  factory VendorCost.fromJson(Json j) => VendorCost(
        vendorName: str(j['vendorName']),
        recordCount: asInt(j['recordCount']),
        qty: asInt(j['qty']),
        totalCost: asDouble(j['totalCost']),
        avgCost: asDouble(j['avgCost']),
      );
}

class TypeCost {
  const TypeCost({required this.type, this.recordCount = 0, this.qty = 0, this.totalCost = 0});

  final String type;
  final int recordCount;
  final int qty;
  final double totalCost;

  factory TypeCost.fromJson(Json j) => TypeCost(
        type: str(j['type']),
        recordCount: asInt(j['recordCount']),
        qty: asInt(j['qty']),
        totalCost: asDouble(j['totalCost']),
      );
}

class ToolCost {
  const ToolCost({
    required this.toolCode,
    required this.name,
    this.recordCount = 0,
    this.qty = 0,
    this.totalCost = 0,
  });

  final String toolCode;
  final String name;
  final int recordCount;
  final int qty;
  final double totalCost;

  factory ToolCost.fromJson(Json j) => ToolCost(
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        recordCount: asInt(j['recordCount']),
        qty: asInt(j['qty']),
        totalCost: asDouble(j['totalCost']),
      );
}

class MaintenanceCostAnalysis {
  const MaintenanceCostAnalysis({
    this.byVendor = const [],
    this.byType = const [],
    this.topTools = const [],
  });

  final List<VendorCost> byVendor;
  final List<TypeCost> byType;
  final List<ToolCost> topTools;

  factory MaintenanceCostAnalysis.fromJson(Json j) => MaintenanceCostAnalysis(
        byVendor: asList(j['byVendor'], VendorCost.fromJson),
        byType: asList(j['byType'], TypeCost.fromJson),
        topTools: asList(j['topTools'], ToolCost.fromJson),
      );
}
