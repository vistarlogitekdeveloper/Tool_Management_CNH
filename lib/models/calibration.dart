import 'json.dart';

/// A row on the Calibration Management grid — the live due position of one
/// controlled instrument.
class CalibrationStatus {
  const CalibrationStatus({
    required this.toolId,
    required this.toolCode,
    required this.toolName,
    this.calibrationRequired = true,
    this.frequencyMonths,
    this.calibrationId,
    this.lastCalibrationDate,
    this.nextDueDate,
    this.daysToDue,
    this.certificateNo,
    this.certificateAttachmentId,
    this.lastResult,
    this.lastCost,
    this.vendorName,
    this.plannedDate,
    this.locationName,
    this.status = 'VALID',
  });

  final int toolId;
  final String toolCode;
  final String toolName;
  final bool calibrationRequired;
  final int? frequencyMonths;
  final int? calibrationId;
  final DateTime? lastCalibrationDate;
  final DateTime? nextDueDate;
  final int? daysToDue;
  final String? certificateNo;
  final String? certificateAttachmentId;
  final String? lastResult;
  final double? lastCost;
  final String? vendorName;
  final DateTime? plannedDate;
  final String? locationName;
  final String status;

  bool get isOverdue => status == 'OVERDUE';
  bool get isDue => const {'OVERDUE', 'DUE_TODAY', 'DUE_SOON'}.contains(status);

  String get dueHint {
    final d = daysToDue;
    if (d == null) return 'Never calibrated';
    if (d < 0) return '${d.abs()} day${d.abs() == 1 ? '' : 's'} overdue';
    if (d == 0) return 'Due today';
    return 'Due in $d day${d == 1 ? '' : 's'}';
  }

  factory CalibrationStatus.fromJson(Json j) => CalibrationStatus(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        toolName: str(j['toolName']),
        calibrationRequired: asBool(j['calibrationRequired'], true),
        frequencyMonths: asIntOrNull(j['frequencyMonths']),
        calibrationId: asIntOrNull(j['calibrationId']),
        lastCalibrationDate: asDate(j['lastCalibrationDate']),
        nextDueDate: asDate(j['nextDueDate']),
        daysToDue: asIntOrNull(j['daysToDue']),
        certificateNo: strOrNull(j['certificateNo']),
        certificateAttachmentId: strOrNull(j['certificateAttachmentId']),
        lastResult: strOrNull(j['lastResult']),
        lastCost: asDoubleOrNull(j['lastCost']),
        vendorName: strOrNull(j['vendorName']),
        plannedDate: asDate(j['plannedDate']),
        locationName: strOrNull(j['locationName']),
        status: str(j['status'], 'VALID'),
      );
}

/// One completed calibration event with its certificate.
class CalibrationRecord {
  const CalibrationRecord({
    required this.id,
    required this.toolId,
    this.calibrationDate,
    this.nextDueDate,
    this.frequencyMonths,
    this.certificateNo,
    this.certificateAttachmentId,
    this.vendorId,
    this.vendorName,
    this.cost = 0,
    this.result = 'PASS',
    this.performedBy,
    this.recordedByName,
    this.remarks,
    this.createdAt,
    this.maintenanceRecordNo,
  });

  final int id;
  final int toolId;
  final DateTime? calibrationDate;
  final DateTime? nextDueDate;
  final int? frequencyMonths;
  final String? certificateNo;
  final String? certificateAttachmentId;
  final int? vendorId;
  final String? vendorName;
  final double cost;
  final String result;
  final String? performedBy;
  final String? recordedByName;
  final String? remarks;
  final DateTime? createdAt;

  /// Set when a FAIL result automatically raised a repair record.
  final String? maintenanceRecordNo;

  factory CalibrationRecord.fromJson(Json j) => CalibrationRecord(
        id: asInt(j['id']),
        toolId: asInt(j['toolId']),
        calibrationDate: asDate(j['calibrationDate']),
        nextDueDate: asDate(j['nextDueDate']),
        frequencyMonths: asIntOrNull(j['frequencyMonths']),
        certificateNo: strOrNull(j['certificateNo']),
        certificateAttachmentId: strOrNull(j['certificateAttachmentId']),
        vendorId: asIntOrNull(j['vendorId']),
        vendorName: strOrNull(j['vendorName']),
        cost: asDouble(j['cost']),
        result: str(j['result'], 'PASS'),
        performedBy: strOrNull(j['performedBy']),
        recordedByName: strOrNull(j['recordedByName']),
        remarks: strOrNull(j['remarks']),
        createdAt: asDate(j['createdAt']),
        maintenanceRecordNo: strOrNull(j['maintenanceRecordNo']),
      );
}

class CalibrationSummary {
  const CalibrationSummary({
    this.overdue = 0,
    this.dueToday = 0,
    this.dueSoon = 0,
    this.valid = 0,
    this.neverCalibrated = 0,
    this.instruments = 0,
    this.dueTotal = 0,
    this.ytdCost = 0,
    this.ytdCount = 0,
  });

  final int overdue;
  final int dueToday;
  final int dueSoon;
  final int valid;
  final int neverCalibrated;
  final int instruments;
  final int dueTotal;
  final double ytdCost;
  final int ytdCount;

  factory CalibrationSummary.fromJson(Json j) => CalibrationSummary(
        overdue: asInt(j['overdue']),
        dueToday: asInt(j['dueToday']),
        dueSoon: asInt(j['dueSoon']),
        valid: asInt(j['valid']),
        neverCalibrated: asInt(j['neverCalibrated']),
        instruments: asInt(j['instruments']),
        dueTotal: asInt(j['dueTotal']),
        ytdCost: asDouble(j['ytdCost']),
        ytdCount: asInt(j['ytdCount']),
      );
}

/// One planned entry on the monthly calibration calendar.
class PlannedCalibration {
  const PlannedCalibration({
    required this.scheduleId,
    required this.toolId,
    required this.toolCode,
    required this.toolName,
    this.vendorName,
    this.status = 'PLANNED',
    this.calibrationStatus,
    this.nextDueDate,
    this.remarks,
  });

  final int scheduleId;
  final int toolId;
  final String toolCode;
  final String toolName;
  final String? vendorName;
  final String status;
  final String? calibrationStatus;
  final DateTime? nextDueDate;
  final String? remarks;

  factory PlannedCalibration.fromJson(Json j) => PlannedCalibration(
        scheduleId: asInt(j['scheduleId']),
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        toolName: str(j['toolName']),
        vendorName: strOrNull(j['vendorName']),
        status: str(j['status'], 'PLANNED'),
        calibrationStatus: strOrNull(j['calibrationStatus']),
        nextDueDate: asDate(j['nextDueDate']),
        remarks: strOrNull(j['remarks']),
      );
}

class CalibrationDay {
  const CalibrationDay({required this.date, this.items = const []});

  final DateTime date;
  final List<PlannedCalibration> items;

  factory CalibrationDay.fromJson(Json j) => CalibrationDay(
        date: asDate(j['date']) ?? DateTime.now(),
        items: asList(j['items'], PlannedCalibration.fromJson),
      );
}

class MonthlyCalibrationPlan {
  const MonthlyCalibrationPlan({required this.month, this.days = const [], this.total = 0});

  final String month;
  final List<CalibrationDay> days;
  final int total;

  factory MonthlyCalibrationPlan.fromJson(Json j) => MonthlyCalibrationPlan(
        month: str(j['month']),
        days: asList(j['days'], CalibrationDay.fromJson),
        total: asInt(j['total']),
      );

  List<PlannedCalibration> itemsOn(DateTime day) {
    for (final d in days) {
      if (d.date.year == day.year && d.date.month == day.month && d.date.day == day.day) {
        return d.items;
      }
    }
    return const [];
  }
}
