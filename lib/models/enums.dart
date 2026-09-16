import '../core/theme/app_colors.dart';

/// The nine RFQ modules plus admin. Codes mirror the backend's `role_modules`,
/// which is what decides the sidebar for each role.
enum AppModule {
  dashboard('dashboard', 'Dashboard', '▦'),
  toolMaster('tool_master', 'Tool Master', '▤'),
  inventory('inventory', 'Inventory', '▣'),
  issueReturn('issue_return', 'Issue & Return', '⇄'),
  tracking('tracking', 'Tool Tracking', '◎'),
  calibration('calibration', 'Calibration', '◷'),
  repairScrap('repair_scrap', 'Repair & Scrap', '✦'),
  purchase('purchase', 'Purchase', '🛒'),
  reports('reports', 'Reports', '▧'),
  admin('admin', 'Administration', '⚙');

  const AppModule(this.code, this.label, this.glyph);

  final String code;
  final String label;
  final String glyph;

  static AppModule? fromCode(String code) {
    for (final m in AppModule.values) {
      if (m.code == code) return m;
    }
    return null;
  }
}

/// Every status token the API can return, with its chip treatment. Keeping this
/// in one place is what makes "LOW" look identical on the dashboard, the
/// inventory grid and a printed PDF.
abstract final class StatusStyles {
  static const _map = <String, StatusPalette>{
    // Stock
    'OK': StatusPalette.green,
    'LOW': StatusPalette.red,
    'IN_STORE': StatusPalette.green,
    'PARTIALLY_ISSUED': StatusPalette.blue,
    'FULLY_ISSUED': StatusPalette.amber,
    'IN_REPAIR': StatusPalette.amber,

    // Tool master
    'ACTIVE': StatusPalette.green,
    'INACTIVE': StatusPalette.slate,
    'OBSOLETE': StatusPalette.red,

    // Issue & return
    'ISSUED': StatusPalette.blue,
    'PARTIALLY_RETURNED': StatusPalette.amber,
    'RETURNED': StatusPalette.green,
    'OVERDUE': StatusPalette.red,
    'LOST': StatusPalette.red,

    // Calibration
    'VALID': StatusPalette.green,
    'SCHEDULED': StatusPalette.slate,
    'DUE_SOON': StatusPalette.amber,
    'DUE_TODAY': StatusPalette.amber,
    'NEVER_CALIBRATED': StatusPalette.red,
    'FAILED': StatusPalette.red,
    'NOT_REQUIRED': StatusPalette.slate,
    'PASS': StatusPalette.green,
    'FAIL': StatusPalette.red,
    'CONDITIONAL': StatusPalette.amber,

    // Approvals
    'PENDING': StatusPalette.amber,
    'APPROVED': StatusPalette.green,
    'REJECTED': StatusPalette.red,

    // Maintenance types
    'REPAIR': StatusPalette.amber,
    'SCRAP': StatusPalette.red,
    'DAMAGE': StatusPalette.red,
    'REPAIRED': StatusPalette.green,
    'UNREPAIRABLE': StatusPalette.red,
    'RETURNED_AS_IS': StatusPalette.slate,

    // Purchase
    'DRAFT': StatusPalette.slate,
    'IN_TRANSIT': StatusPalette.blue,
    'PARTIALLY_RECEIVED': StatusPalette.amber,
    'RECEIVED': StatusPalette.green,
    'CANCELLED': StatusPalette.slate,

    // Reservations
    'FULFILLED': StatusPalette.green,
    'EXPIRED': StatusPalette.slate,

    // Life cycle
    'HEALTHY': StatusPalette.green,
    'MID_LIFE': StatusPalette.amber,
    'REPLACE_SOON': StatusPalette.red,
    'UNTRACKED': StatusPalette.slate,

    // Alerts
    'OPEN': StatusPalette.red,
    'ACKNOWLEDGED': StatusPalette.amber,
    'RESOLVED': StatusPalette.green,
    'CRITICAL': StatusPalette.red,
    'WARNING': StatusPalette.amber,
    'INFO': StatusPalette.blue,

    // Return condition
    'GOOD': StatusPalette.green,
    'DAMAGED': StatusPalette.red,
    'NEEDS_CALIBRATION': StatusPalette.amber,
  };

  static StatusPalette of(String? status) =>
      _map[status?.toUpperCase().replaceAll(' ', '_')] ?? StatusPalette.slate;

  /// 'PARTIALLY_RETURNED' -> 'Partially Returned'
  static String label(String? status) {
    if (status == null || status.isEmpty) return '—';
    return status
        .split(RegExp(r'[_\s]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w.length <= 2 ? w.toUpperCase() : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}

/// Stock ledger movement types, with a human label for the history timeline.
abstract final class TxnLabels {
  static const _map = <String, String>{
    'OPENING': 'Opening balance',
    'PURCHASE_RECEIPT': 'Received from supplier',
    'ADJUST_IN': 'Stock added',
    'ADJUST_OUT': 'Stock removed',
    'ISSUE': 'Issued',
    'RETURN': 'Returned',
    'REPAIR_OUT': 'Sent for repair',
    'REPAIR_IN': 'Back from repair',
    'SCRAP': 'Scrapped',
    'DAMAGE': 'Marked damaged',
    'LOST': 'Written off as lost',
    'FOUND': 'Recovered',
    'TRANSFER': 'Transferred',
    'RESERVE': 'Reserved',
    'RELEASE_RESERVE': 'Reservation released',
  };

  static String of(String code) => _map[code] ?? StatusStyles.label(code);

  /// Movements that add to available stock read green, removals read red.
  static bool isInbound(String code) => const {
        'OPENING', 'PURCHASE_RECEIPT', 'ADJUST_IN', 'RETURN', 'REPAIR_IN', 'FOUND', 'RELEASE_RESERVE',
      }.contains(code);
}

/// Permission codes, mirrored from the backend catalogue so widgets can gate
/// themselves without magic strings.
abstract final class P {
  static const dashboardView = 'dashboard.view';

  static const toolView = 'tool_master.view';
  static const toolCreate = 'tool_master.create';
  static const toolUpdate = 'tool_master.update';
  static const toolDelete = 'tool_master.delete';

  static const inventoryView = 'inventory.view';
  static const inventoryAdjust = 'inventory.adjust';

  static const issueView = 'issue_return.view';
  static const issueCreate = 'issue_return.create';
  static const issueReturn = 'issue_return.return';
  static const issueReserve = 'issue_return.reserve';

  static const trackingView = 'tracking.view';
  static const trackingTransfer = 'tracking.transfer';

  static const calibrationView = 'calibration.view';
  static const calibrationRecord = 'calibration.record';
  static const calibrationSchedule = 'calibration.schedule';

  static const maintenanceView = 'repair_scrap.view';
  static const maintenanceCreate = 'repair_scrap.create';
  static const maintenanceApprove = 'repair_scrap.approve';

  static const purchaseView = 'purchase.view';
  static const purchaseCreate = 'purchase.create';
  static const purchaseApprove = 'purchase.approve';
  static const purchaseReceive = 'purchase.receive';

  static const reportsView = 'reports.view';
  static const reportsExport = 'reports.export';

  static const masterManage = 'admin.masters';
  static const userManage = 'admin.users';
  static const auditView = 'admin.audit';
  static const settingsManage = 'admin.settings';
}
