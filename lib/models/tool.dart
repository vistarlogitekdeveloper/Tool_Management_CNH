import 'dart:ui';

import '../core/theme/app_colors.dart';
import 'json.dart';

class ToolCategoryRef {
  const ToolCategoryRef({required this.id, required this.name, required this.colourHex});

  final int id;
  final String name;
  final String colourHex;

  Color get colour => AppColors.fromHex(colourHex);

  factory ToolCategoryRef.fromJson(Json j) => ToolCategoryRef(
        id: asInt(j['id']),
        name: str(j['name']),
        colourHex: str(j['colour'], '#64748b'),
      );
}

class ToolLocationRef {
  const ToolLocationRef({required this.id, required this.name, this.shop, this.line, this.station});

  final int id;
  final String name;
  final String? shop;
  final String? line;
  final String? station;

  factory ToolLocationRef.fromJson(Json j) => ToolLocationRef(
        id: asInt(j['id']),
        name: str(j['name']),
        shop: strOrNull(j['shop']),
        line: strOrNull(j['line']),
        station: strOrNull(j['station']),
      );
}

/// The eight quantity buckets that describe where every unit of a tool is.
class ToolStock {
  const ToolStock({
    this.total = 0,
    this.available = 0,
    this.issued = 0,
    this.reserved = 0,
    this.repair = 0,
    this.scrap = 0,
    this.damaged = 0,
    this.lost = 0,
    this.minStock = 0,
    this.reorderLevel = 0,
    this.reorderQty = 0,
    this.isLowStock = false,
    this.stockPercent = 0,
    this.inventoryValue = 0,
  });

  final int total;
  final int available;
  final int issued;
  final int reserved;
  final int repair;
  final int scrap;
  final int damaged;
  final int lost;
  final int minStock;
  final int reorderLevel;
  final int reorderQty;
  final bool isLowStock;
  final double stockPercent;
  final double inventoryValue;

  factory ToolStock.fromJson(Json j) => ToolStock(
        total: asInt(j['total']),
        available: asInt(j['available']),
        issued: asInt(j['issued']),
        reserved: asInt(j['reserved']),
        repair: asInt(j['repair']),
        scrap: asInt(j['scrap']),
        damaged: asInt(j['damaged']),
        lost: asInt(j['lost']),
        minStock: asInt(j['minStock']),
        reorderLevel: asInt(j['reorderLevel']),
        reorderQty: asInt(j['reorderQty']),
        isLowStock: asBool(j['isLowStock']),
        stockPercent: asDouble(j['stockPercent']),
        inventoryValue: asDouble(j['inventoryValue']),
      );

  String get statusCode => isLowStock ? 'LOW' : 'OK';

  /// How far below the minimum the tool is; 0 when healthy.
  int get shortfall => (minStock - available).clamp(0, 1 << 30);
}

class ToolCalibrationInfo {
  const ToolCalibrationInfo({
    this.required = false,
    this.frequencyMonths,
    this.lastCalibrationDate,
    this.nextDueDate,
    this.certificateNo,
    this.certificateAttachmentId,
    this.status = 'NOT_REQUIRED',
    this.daysToDue,
    this.vendorName,
    this.plannedDate,
  });

  final bool required;
  final int? frequencyMonths;
  final DateTime? lastCalibrationDate;
  final DateTime? nextDueDate;
  final String? certificateNo;
  final String? certificateAttachmentId;
  final String status;
  final int? daysToDue;
  final String? vendorName;
  final DateTime? plannedDate;

  factory ToolCalibrationInfo.fromJson(Json j) => ToolCalibrationInfo(
        required: asBool(j['required']),
        frequencyMonths: asIntOrNull(j['frequencyMonths']),
        lastCalibrationDate: asDate(j['lastCalibrationDate']),
        nextDueDate: asDate(j['nextDueDate']),
        certificateNo: strOrNull(j['certificateNo']),
        certificateAttachmentId: strOrNull(j['certificateAttachmentId']),
        status: str(j['status'], 'NOT_REQUIRED'),
        daysToDue: asIntOrNull(j['daysToDue']),
        vendorName: strOrNull(j['vendorName']),
        plannedDate: asDate(j['plannedDate']),
      );

  /// Mirrors the server-side gate in issues.service.js — these are the states
  /// that refuse an issue. 'FAILED' means the last certificate came back out of
  /// tolerance.
  bool get isBlocking =>
      status == 'OVERDUE' || status == 'NEVER_CALIBRATED' || status == 'FAILED';
}

class ToolLifecycleInfo {
  const ToolLifecycleInfo({this.expectedCycles, this.consumedCycles = 0});

  final int? expectedCycles;
  final int consumedCycles;

  factory ToolLifecycleInfo.fromJson(Json j) => ToolLifecycleInfo(
        expectedCycles: asIntOrNull(j['expectedCycles']),
        consumedCycles: asInt(j['consumedCycles']),
      );

  double? get consumedPercent {
    final expected = expectedCycles;
    if (expected == null || expected == 0) return null;
    return ((consumedCycles / expected) * 100).clamp(0, 100);
  }

  String get stage {
    final pct = consumedPercent;
    if (pct == null) return 'UNTRACKED';
    if (pct >= 85) return 'REPLACE_SOON';
    if (pct >= 60) return 'MID_LIFE';
    return 'HEALTHY';
  }
}

class Attachment {
  const Attachment({
    required this.id,
    required this.category,
    required this.fileName,
    this.mimeType,
    this.sizeBytes = 0,
    this.uploadedAt,
    this.uploadedByName,
    this.url,
  });

  final String id;
  final String category;
  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final DateTime? uploadedAt;
  final String? uploadedByName;
  final String? url;

  factory Attachment.fromJson(Json j) => Attachment(
        id: str(j['id']),
        category: str(j['category']),
        fileName: str(j['fileName']),
        mimeType: strOrNull(j['mimeType']),
        sizeBytes: asInt(j['sizeBytes']),
        uploadedAt: asDate(j['uploadedAt']),
        uploadedByName: strOrNull(j['uploadedByName']),
        url: strOrNull(j['url']),
      );

  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class OpenIssueRef {
  const OpenIssueRef({
    required this.issueId,
    required this.issueNo,
    required this.employeeName,
    required this.qtyOutstanding,
    this.employeeCode,
    this.department,
    this.location,
    this.issueDate,
    this.dueDate,
    this.status = 'ISSUED',
    this.isOverdue = false,
  });

  final int issueId;
  final String issueNo;
  final String employeeName;
  final String? employeeCode;
  final String? department;
  final String? location;
  final int qtyOutstanding;
  final DateTime? issueDate;
  final DateTime? dueDate;
  final String status;
  final bool isOverdue;

  factory OpenIssueRef.fromJson(Json j) => OpenIssueRef(
        issueId: asInt(j['issueId']),
        issueNo: str(j['issueNo']),
        employeeName: str(j['employeeName']),
        employeeCode: strOrNull(j['employeeCode']),
        department: strOrNull(j['department']),
        location: strOrNull(j['location']),
        qtyOutstanding: asInt(j['qtyOutstanding']),
        issueDate: asDate(j['issueDate']),
        dueDate: asDate(j['dueDate']),
        status: str(j['status'], 'ISSUED'),
        isOverdue: asBool(j['isOverdue']),
      );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.type,
    required this.qty,
    this.availableAfter = 0,
    this.totalAfter = 0,
    this.remarks,
    this.employeeName,
    this.byUser,
    this.at,
    this.toolCode,
    this.toolName,
    this.fromLocation,
    this.toLocation,
  });

  final int id;
  final String type;
  final int qty;
  final int availableAfter;
  final int totalAfter;
  final String? remarks;
  final String? employeeName;
  final String? byUser;
  final DateTime? at;
  final String? toolCode;
  final String? toolName;
  final String? fromLocation;
  final String? toLocation;

  factory StockMovement.fromJson(Json j) => StockMovement(
        id: asInt(j['id']),
        type: str(j['type']),
        qty: asInt(j['qty']),
        availableAfter: asInt(j['availableAfter']),
        totalAfter: asInt(j['totalAfter']),
        remarks: strOrNull(j['remarks']),
        employeeName: strOrNull(j['employeeName']),
        byUser: strOrNull(j['byUser']),
        at: asDate(j['at']),
        toolCode: strOrNull(j['toolCode']),
        toolName: strOrNull(j['toolName']),
        fromLocation: strOrNull(j['fromLocation']),
        toLocation: strOrNull(j['toLocation']),
      );
}

/// A row in the Tool Master grid, and the full record behind the detail sheet.
class Tool {
  const Tool({
    required this.id,
    required this.toolCode,
    required this.name,
    required this.category,
    required this.stock,
    this.partNumber,
    this.specification,
    this.description,
    this.manufacturer,
    this.uom = 'NOS',
    this.unitCost = 0,
    this.barcode,
    this.status = 'ACTIVE',
    this.location,
    this.calibration = const ToolCalibrationInfo(),
    this.lifecycle = const ToolLifecycleInfo(),
    this.purchaseDate,
    this.warrantyExpiry,
    this.drawingAttachmentId,
    this.imageAttachmentId,
    this.openIssues = const [],
    this.attachments = const [],
    this.recentTransactions = const [],
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String toolCode;
  final String name;
  final String? partNumber;
  final String? specification;
  final String? description;
  final String? manufacturer;
  final String uom;
  final double unitCost;
  final String? barcode;
  final String status;
  final ToolCategoryRef category;
  final ToolLocationRef? location;
  final ToolStock stock;
  final ToolCalibrationInfo calibration;
  final ToolLifecycleInfo lifecycle;
  final DateTime? purchaseDate;
  final DateTime? warrantyExpiry;
  final String? drawingAttachmentId;
  final String? imageAttachmentId;
  final List<OpenIssueRef> openIssues;
  final List<Attachment> attachments;
  final List<StockMovement> recentTransactions;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Tool.fromJson(Json j) => Tool(
        id: asInt(j['id']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        partNumber: strOrNull(j['partNumber']),
        specification: strOrNull(j['specification']),
        description: strOrNull(j['description']),
        manufacturer: strOrNull(j['manufacturer']),
        uom: str(j['uom'], 'NOS'),
        unitCost: asDouble(j['unitCost']),
        barcode: strOrNull(j['barcode']),
        status: str(j['status'], 'ACTIVE'),
        category: ToolCategoryRef.fromJson(asMap(j['category'])),
        location: asMapOrNull(j['location']) == null ? null : ToolLocationRef.fromJson(asMap(j['location'])),
        stock: ToolStock.fromJson(asMap(j['stock'])),
        calibration: ToolCalibrationInfo.fromJson(asMap(j['calibration'])),
        lifecycle: ToolLifecycleInfo.fromJson(asMap(j['lifecycle'])),
        purchaseDate: asDate(j['purchaseDate']),
        warrantyExpiry: asDate(j['warrantyExpiry']),
        drawingAttachmentId: strOrNull(j['drawingAttachmentId']),
        imageAttachmentId: strOrNull(j['imageAttachmentId']),
        openIssues: asList(j['openIssues'], OpenIssueRef.fromJson),
        attachments: asList(j['attachments'], Attachment.fromJson),
        recentTransactions: asList(j['recentTransactions'], StockMovement.fromJson),
        createdAt: asDate(j['createdAt']),
        updatedAt: asDate(j['updatedAt']),
      );

  String get displayLocation => location?.name ?? '— In Store —';
}

/// Slim record for typeahead pickers.
class ToolOption {
  const ToolOption({
    required this.id,
    required this.toolCode,
    required this.name,
    this.partNumber,
    this.availableQty = 0,
    this.minStock = 0,
    this.uom = 'NOS',
    this.unitCost = 0,
    this.categoryName,
    this.locationName,
    this.calibrationRequired = false,
  });

  final int id;
  final String toolCode;
  final String name;
  final String? partNumber;
  final int availableQty;
  final int minStock;
  final String uom;
  final double unitCost;
  final String? categoryName;
  final String? locationName;
  final bool calibrationRequired;

  factory ToolOption.fromJson(Json j) => ToolOption(
        id: asInt(j['id']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        partNumber: strOrNull(j['partNumber']),
        availableQty: asInt(j['availableQty']),
        minStock: asInt(j['minStock']),
        uom: str(j['uom'], 'NOS'),
        unitCost: asDouble(j['unitCost']),
        categoryName: strOrNull(j['categoryName']),
        locationName: strOrNull(j['locationName']),
        calibrationRequired: asBool(j['calibrationRequired']),
      );

  String get label => '$toolCode — $name';
  String get availabilityHint => '$availableQty available in store · min $minStock';
}

/// One entry in the merged tool-history timeline.
class ToolHistoryEvent {
  const ToolHistoryEvent({
    required this.at,
    required this.stream,
    required this.event,
    this.qty = 0,
    this.detail,
    this.actor,
    this.party,
    this.referenceType,
    this.referenceId,
  });

  final DateTime? at;
  final String stream;
  final String event;
  final int qty;
  final String? detail;
  final String? actor;
  final String? party;
  final String? referenceType;
  final String? referenceId;

  factory ToolHistoryEvent.fromJson(Json j) => ToolHistoryEvent(
        at: asDate(j['at']),
        stream: str(j['stream']),
        event: str(j['event']),
        qty: asInt(j['qty']),
        detail: strOrNull(j['detail']),
        actor: strOrNull(j['actor']),
        party: strOrNull(j['party']),
        referenceType: strOrNull(j['referenceType']),
        referenceId: strOrNull(j['referenceId']),
      );
}

class ToolHistory {
  const ToolHistory({required this.toolCode, required this.name, this.events = const []});

  final String toolCode;
  final String name;
  final List<ToolHistoryEvent> events;

  factory ToolHistory.fromJson(Json j) {
    final tool = asMap(j['tool']);
    return ToolHistory(
      toolCode: str(tool['toolCode']),
      name: str(tool['name']),
      events: asList(j['events'], ToolHistoryEvent.fromJson),
    );
  }
}
