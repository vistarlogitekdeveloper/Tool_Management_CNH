import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/alert.dart';
import '../../../models/json.dart';

class AlertsRepository {
  AlertsRepository(this._api);

  final ApiClient _api;

  Future<PagedResult<AlertItem>> list({String? status, String? type, String? severity, int page = 1}) =>
      _api.getPaged('/alerts',
          query: {'status': status, 'type': type, 'severity': severity, 'page': page, 'limit': 50},
          parse: AlertItem.fromJson);

  Future<AlertSummary> summary() async => AlertSummary.fromJson(await _api.get<Json>('/alerts/summary'));

  Future<void> acknowledge(int id) => _api.post<Json>('/alerts/$id/acknowledge');

  /// Forces the server to re-evaluate every alert rule now.
  Future<Json> sweep() => _api.post<Json>('/alerts/sweep');

  Future<NotificationFeed> notifications({bool unreadOnly = false, int limit = 30}) async =>
      NotificationFeed.fromJson(
          await _api.get<Json>('/alerts/notifications', query: {'unreadOnly': unreadOnly, 'limit': limit}));

  /* ── Alert delivery (email / SMS) ─────────────────────────────────────── */

  Future<DeliverySummary> deliverySummary() async =>
      DeliverySummary.fromJson(await _api.get<Json>('/alerts/deliveries/summary'));

  Future<List<DeliveryRecord>> deliveryLog({String? status, String? channel, int limit = 50}) async {
    final data = await _api.get<List<dynamic>>('/alerts/deliveries',
        query: {'status': status, 'channel': channel, 'limit': limit});
    return data
        .whereType<Map>()
        .map((e) => DeliveryRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Sends whatever is queued now, rather than waiting for the next cron tick.
  Future<Json> dispatchDeliveries() => _api.post<Json>('/alerts/deliveries/dispatch');

  /// Sends a test message to the signed-in user own address, to prove the
  /// transport works before anyone relies on it.
  Future<Json> testDelivery(String channel) =>
      _api.post<Json>('/alerts/deliveries/test', data: {'channel': channel});

  Future<int> markRead({List<int>? ids, bool all = false}) async {
    final data = await _api.post<Json>('/alerts/notifications/read', data: {
      if (ids != null) 'ids': ids,
      if (all) 'all': true,
    });
    return (data['unreadCount'] as num?)?.toInt() ?? 0;
  }
}

final alertsRepositoryProvider =
    Provider<AlertsRepository>((ref) => AlertsRepository(ref.watch(apiClientProvider)));

final alertsListProvider = FutureProvider.autoDispose.family<PagedResult<AlertItem>, String?>(
  (ref, status) => ref.watch(alertsRepositoryProvider).list(status: status),
);

final deliverySummaryProvider = FutureProvider.autoDispose<DeliverySummary>(
  (ref) => ref.watch(alertsRepositoryProvider).deliverySummary(),
);

/// Which slice of the delivery log the Administration panel is showing.
final deliveryLogFilterProvider = StateProvider<String?>((ref) => null);

final deliveryLogProvider = FutureProvider.autoDispose<List<DeliveryRecord>>(
  (ref) => ref
      .watch(alertsRepositoryProvider)
      .deliveryLog(status: ref.watch(deliveryLogFilterProvider)),
);

final alertSummaryProvider = FutureProvider.autoDispose<AlertSummary>(
  (ref) => ref.watch(alertsRepositoryProvider).summary(),
);

/// The bell menu. Re-polls on a slow timer so a supervisor sees a new overdue
/// return without reloading the page.
final notificationFeedProvider = StreamProvider.autoDispose<NotificationFeed>((ref) async* {
  final repo = ref.watch(alertsRepositoryProvider);
  yield await repo.notifications();

  final timer = Stream<void>.periodic(AppConfig.alertPollInterval);
  await for (final _ in timer) {
    try {
      yield await repo.notifications();
    } catch (_) {
      // A failed poll should not tear down the stream — try again next tick.
    }
  }
});

/// Unread badge count, derived so widgets can watch just the number.
final unreadCountProvider = Provider.autoDispose<int>(
  (ref) => ref.watch(notificationFeedProvider).valueOrNull?.unreadCount ?? 0,
);
