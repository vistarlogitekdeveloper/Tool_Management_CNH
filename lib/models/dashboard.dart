import 'dart:ui';

import '../core/theme/app_colors.dart';
import 'json.dart';

/// A labelled value with a colour — the shape every chart on the dashboard eats.
class ChartSlice {
  const ChartSlice({required this.label, required this.value, required this.colour, this.extra});

  final String label;
  final num value;
  final Color colour;
  final num? extra;

  factory ChartSlice.fromJson(Json j) => ChartSlice(
        label: str(j['label']),
        value: asDouble(j['value']),
        colour: AppColors.fromHex(strOrNull(j['colour'])),
        extra: asDoubleOrNull(j['available'] ?? j['toolCount']),
      );
}

class TrendPoint {
  const TrendPoint({required this.date, this.issues = 0, this.qty = 0, this.returns = 0});

  final DateTime date;
  final int issues;
  final int qty;
  final int returns;

  factory TrendPoint.fromJson(Json j) => TrendPoint(
        date: asDate(j['date']) ?? DateTime.now(),
        issues: asInt(j['issues']),
        qty: asInt(j['qty']),
        returns: asInt(j['returns']),
      );
}

class DashboardKpis {
  const DashboardKpis({
    this.totalTools = 0,
    this.toolTypes = 0,
    this.available = 0,
    this.issued = 0,
    this.inRepair = 0,
    this.scrapped = 0,
    this.damaged = 0,
    this.lost = 0,
    this.lowStockCount = 0,
    this.inventoryValue = 0,
    this.availablePercent = 0,
    this.utilisationPercent = 0,
    this.calibrationOverdue = 0,
    this.calibrationDueSoon = 0,
    this.openIssues = 0,
    this.overdueReturns = 0,
    this.issuedToday = 0,
    this.pendingApprovals = 0,
  });

  final int totalTools;
  final int toolTypes;
  final int available;
  final int issued;
  final int inRepair;
  final int scrapped;
  final int damaged;
  final int lost;
  final int lowStockCount;
  final double inventoryValue;
  final int availablePercent;
  final int utilisationPercent;
  final int calibrationOverdue;
  final int calibrationDueSoon;
  final int openIssues;
  final int overdueReturns;
  final int issuedToday;
  final int pendingApprovals;

  int get calibrationDueTotal => calibrationOverdue + calibrationDueSoon;

  factory DashboardKpis.fromJson(Json j) => DashboardKpis(
        totalTools: asInt(j['totalTools']),
        toolTypes: asInt(j['toolTypes']),
        available: asInt(j['available']),
        issued: asInt(j['issued']),
        inRepair: asInt(j['inRepair']),
        scrapped: asInt(j['scrapped']),
        damaged: asInt(j['damaged']),
        lost: asInt(j['lost']),
        lowStockCount: asInt(j['lowStockCount']),
        inventoryValue: asDouble(j['inventoryValue']),
        availablePercent: asInt(j['availablePercent']),
        utilisationPercent: asInt(j['utilisationPercent']),
        calibrationOverdue: asInt(j['calibrationOverdue']),
        calibrationDueSoon: asInt(j['calibrationDueSoon']),
        openIssues: asInt(j['openIssues']),
        overdueReturns: asInt(j['overdueReturns']),
        issuedToday: asInt(j['issuedToday']),
        pendingApprovals: asInt(j['pendingApprovals']),
      );
}

class CalibrationDueItem {
  const CalibrationDueItem({
    required this.toolId,
    required this.toolCode,
    required this.toolName,
    this.locationName,
    this.nextDueDate,
    this.daysToDue,
    this.status = 'DUE_SOON',
  });

  final int toolId;
  final String toolCode;
  final String toolName;
  final String? locationName;
  final DateTime? nextDueDate;
  final int? daysToDue;
  final String status;

  factory CalibrationDueItem.fromJson(Json j) => CalibrationDueItem(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        toolName: str(j['toolName']),
        locationName: strOrNull(j['locationName']),
        nextDueDate: asDate(j['nextDueDate']),
        daysToDue: asIntOrNull(j['daysToDue']),
        status: str(j['status'], 'DUE_SOON'),
      );
}

class ActivityItem {
  const ActivityItem({
    required this.issueId,
    required this.issueNo,
    required this.toolCode,
    required this.toolName,
    required this.employeeName,
    this.locationName,
    this.qty = 0,
    this.status = 'ISSUED',
    this.issueDate,
    this.dueDate,
  });

  final int issueId;
  final String issueNo;
  final String toolCode;
  final String toolName;
  final String employeeName;
  final String? locationName;
  final int qty;
  final String status;
  final DateTime? issueDate;
  final DateTime? dueDate;

  String get initials {
    final parts = employeeName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  factory ActivityItem.fromJson(Json j) => ActivityItem(
        issueId: asInt(j['issueId']),
        issueNo: str(j['issueNo']),
        toolCode: str(j['toolCode']),
        toolName: str(j['toolName']),
        employeeName: str(j['employeeName']),
        locationName: strOrNull(j['locationName']),
        qty: asInt(j['qty']),
        status: str(j['status'], 'ISSUED'),
        issueDate: asDate(j['issueDate']),
        dueDate: asDate(j['dueDate']),
      );
}

class LowStockPreview {
  const LowStockPreview({
    required this.toolId,
    required this.toolCode,
    required this.name,
    this.available = 0,
    this.total = 0,
    this.minStock = 0,
    this.stockPercent = 0,
  });

  final int toolId;
  final String toolCode;
  final String name;
  final int available;
  final int total;
  final int minStock;
  final double stockPercent;

  factory LowStockPreview.fromJson(Json j) => LowStockPreview(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        available: asInt(j['available']),
        total: asInt(j['total']),
        minStock: asInt(j['minStock']),
        stockPercent: asDouble(j['stockPercent']),
      );
}

class ShopUtilisation {
  const ShopUtilisation({
    required this.shop,
    this.toolCount = 0,
    this.totalQty = 0,
    this.issuedQty = 0,
    this.availableQty = 0,
    this.utilisationPercent = 0,
  });

  final String shop;
  final int toolCount;
  final int totalQty;
  final int issuedQty;
  final int availableQty;
  final int utilisationPercent;

  factory ShopUtilisation.fromJson(Json j) => ShopUtilisation(
        shop: str(j['shop']),
        toolCount: asInt(j['toolCount']),
        totalQty: asInt(j['totalQty']),
        issuedQty: asInt(j['issuedQty']),
        availableQty: asInt(j['availableQty']),
        utilisationPercent: asInt(j['utilisationPercent']),
      );
}

/// The whole dashboard, from one request.
class DashboardOverview {
  const DashboardOverview({
    required this.kpis,
    this.generatedAt,
    this.fleetByStatus = const [],
    this.byCategory = const [],
    this.issueTrend = const [],
    this.calibrationDue = const [],
    this.recentActivity = const [],
    this.lowStock = const [],
    this.alerts = const [],
    this.utilisationByShop = const [],
  });

  final DateTime? generatedAt;
  final DashboardKpis kpis;
  final List<ChartSlice> fleetByStatus;
  final List<ChartSlice> byCategory;
  final List<TrendPoint> issueTrend;
  final List<CalibrationDueItem> calibrationDue;
  final List<ActivityItem> recentActivity;
  final List<LowStockPreview> lowStock;
  final List<AlertPreview> alerts;
  final List<ShopUtilisation> utilisationByShop;

  factory DashboardOverview.fromJson(Json j) => DashboardOverview(
        generatedAt: asDate(j['generatedAt']),
        kpis: DashboardKpis.fromJson(asMap(j['kpis'])),
        fleetByStatus: asList(j['fleetByStatus'], ChartSlice.fromJson),
        byCategory: asList(j['byCategory'], ChartSlice.fromJson),
        issueTrend: asList(j['issueTrend'], TrendPoint.fromJson),
        calibrationDue: asList(j['calibrationDue'], CalibrationDueItem.fromJson),
        recentActivity: asList(j['recentActivity'], ActivityItem.fromJson),
        lowStock: asList(j['lowStock'], LowStockPreview.fromJson),
        alerts: asList(j['alerts'], AlertPreview.fromJson),
        utilisationByShop: asList(j['utilisationByShop'], ShopUtilisation.fromJson),
      );
}

class AlertPreview {
  const AlertPreview({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    this.message,
    this.entityType,
    this.entityId,
    this.raisedAt,
  });

  final int id;
  final String type;
  final String severity;
  final String title;
  final String? message;
  final String? entityType;
  final String? entityId;
  final DateTime? raisedAt;

  factory AlertPreview.fromJson(Json j) => AlertPreview(
        id: asInt(j['id']),
        type: str(j['type']),
        severity: str(j['severity'], 'WARNING'),
        title: str(j['title']),
        message: strOrNull(j['message']),
        entityType: strOrNull(j['entityType']),
        entityId: strOrNull(j['entityId']),
        raisedAt: asDate(j['raisedAt']),
      );
}
