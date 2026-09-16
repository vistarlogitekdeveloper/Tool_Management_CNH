import 'json.dart';

class AlertItem {
  const AlertItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.title,
    this.message,
    this.entityType,
    this.entityId,
    this.status = 'OPEN',
    this.raisedAt,
    this.lastSeenAt,
    this.acknowledgedAt,
    this.acknowledgedByName,
    this.resolvedAt,
  });

  final int id;
  final String type;
  final String severity;
  final String title;
  final String? message;
  final String? entityType;
  final String? entityId;
  final String status;
  final DateTime? raisedAt;
  final DateTime? lastSeenAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedByName;
  final DateTime? resolvedAt;

  bool get isOpen => status == 'OPEN';
  bool get isCritical => severity == 'CRITICAL';

  /// Where tapping the alert should take the user.
  String? get deepLink => switch (type) {
        'LOW_STOCK' => '/inventory',
        'CALIBRATION_DUE' || 'CALIBRATION_OVERDUE' => '/calibration',
        'RETURN_OVERDUE' => '/issues',
        'APPROVAL_PENDING' => '/maintenance',
        'PO_DELAYED' => '/purchase',
        _ => null,
      };

  factory AlertItem.fromJson(Json j) => AlertItem(
        id: asInt(j['id']),
        type: str(j['type']),
        severity: str(j['severity'], 'WARNING'),
        title: str(j['title']),
        message: strOrNull(j['message']),
        entityType: strOrNull(j['entityType']),
        entityId: strOrNull(j['entityId']),
        status: str(j['status'], 'OPEN'),
        raisedAt: asDate(j['raisedAt']),
        lastSeenAt: asDate(j['lastSeenAt']),
        acknowledgedAt: asDate(j['acknowledgedAt']),
        acknowledgedByName: strOrNull(j['acknowledgedByName']),
        resolvedAt: asDate(j['resolvedAt']),
      );
}

class AlertSummary {
  const AlertSummary({
    this.open = 0,
    this.acknowledged = 0,
    this.critical = 0,
    this.lowStock = 0,
    this.calibration = 0,
    this.overdueReturns = 0,
    this.total = 0,
  });

  final int open;
  final int acknowledged;
  final int critical;
  final int lowStock;
  final int calibration;
  final int overdueReturns;
  final int total;

  factory AlertSummary.fromJson(Json j) => AlertSummary(
        open: asInt(j['open']),
        acknowledged: asInt(j['acknowledged']),
        critical: asInt(j['critical']),
        lowStock: asInt(j['lowStock']),
        calibration: asInt(j['calibration']),
        overdueReturns: asInt(j['overdueReturns']),
        total: asInt(j['total']),
      );
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    this.body,
    this.link,
    this.isRead = false,
    this.createdAt,
    this.alertType,
    this.severity,
    this.entityType,
    this.entityId,
  });

  final int id;
  final String title;
  final String? body;
  final String? link;
  final bool isRead;
  final DateTime? createdAt;
  final String? alertType;
  final String? severity;
  final String? entityType;
  final String? entityId;

  factory AppNotification.fromJson(Json j) => AppNotification(
        id: asInt(j['id']),
        title: str(j['title']),
        body: strOrNull(j['body']),
        link: strOrNull(j['link']),
        isRead: asBool(j['isRead']),
        createdAt: asDate(j['createdAt']),
        alertType: strOrNull(j['alertType']),
        severity: strOrNull(j['severity']),
        entityType: strOrNull(j['entityType']),
        entityId: strOrNull(j['entityId']),
      );
}

class NotificationFeed {
  const NotificationFeed({this.unreadCount = 0, this.items = const []});

  final int unreadCount;
  final List<AppNotification> items;

  factory NotificationFeed.fromJson(Json j) => NotificationFeed(
        unreadCount: asInt(j['unreadCount']),
        items: asList(j['items'], AppNotification.fromJson),
      );
}

/* ── Alert delivery (email / SMS) ────────────────────────────────────────── */

/// One channel's configuration, as the server sees it.
///
/// `configured` means the transport has its environment set; `enabled` is the
/// separate switch under Workflow Rules. Both must be true before anything is
/// sent, and `reason` says which one is missing.
class TransportStatus {
  const TransportStatus({
    required this.configured,
    this.host,
    this.from,
    this.reason,
    this.authenticated = false,
  });

  final bool configured;
  final String? host;
  final String? from;
  final String? reason;
  final bool authenticated;

  factory TransportStatus.fromJson(Json j) => TransportStatus(
        configured: asBool(j['configured']),
        // The email transport reports a host; the SMS one reports an endpoint
        // host only, because the webhook URL can carry an API key.
        host: strOrNull(j['host']) ?? strOrNull(j['endpoint']),
        from: strOrNull(j['from']),
        reason: strOrNull(j['reason']),
        authenticated: asBool(j['authenticated']),
      );
}

class DeliverySummary {
  const DeliverySummary({
    this.pending = 0,
    this.sent = 0,
    this.failed = 0,
    this.skipped = 0,
    this.sent24h = 0,
    this.lastSentAt,
    this.emailEnabled = false,
    this.smsEnabled = false,
    this.minSeverity = 'WARNING',
    required this.email,
    required this.sms,
  });

  final int pending;
  final int sent;
  final int failed;
  final int skipped;
  final int sent24h;
  final DateTime? lastSentAt;
  final bool emailEnabled;
  final bool smsEnabled;
  final String minSeverity;
  final TransportStatus email;
  final TransportStatus sms;

  factory DeliverySummary.fromJson(Json j) {
    final transports = asMap(j['transports']);
    final enabled = asMap(j['enabled']);
    return DeliverySummary(
      pending: asInt(j['pending']),
      sent: asInt(j['sent']),
      failed: asInt(j['failed']),
      skipped: asInt(j['skipped']),
      sent24h: asInt(j['sent24h']),
      lastSentAt: asDate(j['lastSentAt']),
      emailEnabled: asBool(enabled['email']),
      smsEnabled: asBool(enabled['sms']),
      minSeverity: str(j['minSeverity'], 'WARNING'),
      email: TransportStatus.fromJson(asMap(transports['email'])),
      sms: TransportStatus.fromJson(asMap(transports['sms'])),
    );
  }

  /// True when a channel is switched on but its transport is not set up — the
  /// state where a plant thinks reminders are going out and they are not.
  bool get emailMisconfigured => emailEnabled && !email.configured;
  bool get smsMisconfigured => smsEnabled && !sms.configured;
  bool get anyLive => (emailEnabled && email.configured) || (smsEnabled && sms.configured);
}

class DeliveryRecord {
  const DeliveryRecord({
    required this.id,
    required this.channel,
    required this.status,
    this.recipient,
    this.userName,
    this.alertType,
    this.subject,
    this.severity,
    this.attempts = 0,
    this.lastError,
    this.queuedAt,
    this.sentAt,
    this.nextAttemptAt,
  });

  final int id;
  final String channel;
  final String status;

  /// Masked by the server — enough to recognise, not enough to be a directory.
  final String? recipient;
  final String? userName;
  final String? alertType;
  final String? subject;
  final String? severity;
  final int attempts;
  final String? lastError;
  final DateTime? queuedAt;
  final DateTime? sentAt;
  final DateTime? nextAttemptAt;

  factory DeliveryRecord.fromJson(Json j) => DeliveryRecord(
        id: asInt(j['id']),
        channel: str(j['channel']),
        status: str(j['status']),
        recipient: strOrNull(j['recipient']),
        userName: strOrNull(j['userName']),
        alertType: strOrNull(j['alertType']),
        subject: strOrNull(j['subject']),
        severity: strOrNull(j['severity']),
        attempts: asInt(j['attempts']),
        lastError: strOrNull(j['lastError']),
        queuedAt: asDate(j['queuedAt']),
        sentAt: asDate(j['sentAt']),
        nextAttemptAt: asDate(j['nextAttemptAt']),
      );

  bool get isEmail => channel == 'EMAIL';
}
