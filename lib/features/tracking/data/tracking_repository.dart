import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/providers.dart';
import '../../../models/json.dart';
import '../../../models/tracking.dart';

class TrackingRepository {
  TrackingRepository(this._api);

  final ApiClient _api;

  Future<List<TrackingZone>> zones() async {
    final data = await _api.get<List<dynamic>>('/tracking/zones');
    return data.whereType<Map>().map((e) => TrackingZone.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<PagedResult<TrackedTool>> live(TrackingQuery query) =>
      _api.getPaged('/tracking/live', query: query.toQuery(), parse: TrackedTool.fromJson);

  Future<ToolLocation> locate(int toolId) async =>
      ToolLocation.fromJson(await _api.get<Json>('/tracking/locate/$toolId'));

  Future<List<ToolTransfer>> transfers({int? toolId}) async {
    final data = await _api.get<List<dynamic>>('/tracking/transfers', query: {'toolId': toolId});
    return data.whereType<Map>().map((e) => ToolTransfer.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<ToolTransfer> transfer({
    required int toolId,
    required int toLocationId,
    int qty = 1,
    String? reason,
  }) async =>
      ToolTransfer.fromJson(await _api.post<Json>('/tracking/transfers', data: {
        'toolId': toolId,
        'toLocationId': toLocationId,
        'qty': qty,
        if (reason?.isNotEmpty == true) 'reason': reason,
      }));
}

@immutable
class TrackingQuery {
  const TrackingQuery({this.q = '', this.shop, this.locationId, this.status, this.page = 1, this.limit = 50});

  final String q;
  final String? shop;
  final int? locationId;
  final String? status;
  final int page;
  final int limit;

  Map<String, dynamic> toQuery() => {
        if (q.trim().isNotEmpty) 'q': q.trim(),
        if (shop != null) 'shop': shop,
        if (locationId != null) 'locationId': locationId,
        if (status != null) 'status': status,
        'page': page,
        'limit': limit,
      };

  TrackingQuery copyWith({
    String? q,
    String? shop,
    int? locationId,
    String? status,
    int? page,
    int? limit,
    bool clearShop = false,
    bool clearStatus = false,
  }) =>
      TrackingQuery(
        q: q ?? this.q,
        shop: clearShop ? null : (shop ?? this.shop),
        locationId: locationId ?? this.locationId,
        status: clearStatus ? null : (status ?? this.status),
        page: page ?? 1,
        limit: limit ?? this.limit,
      );

  @override
  bool operator ==(Object other) =>
      other is TrackingQuery &&
      other.q == q &&
      other.shop == shop &&
      other.locationId == locationId &&
      other.status == status &&
      other.page == page &&
      other.limit == limit;

  @override
  int get hashCode => Object.hash(q, shop, locationId, status, page, limit);
}

final trackingRepositoryProvider =
    Provider<TrackingRepository>((ref) => TrackingRepository(ref.watch(apiClientProvider)));

final trackingQueryProvider = StateProvider<TrackingQuery>((ref) => const TrackingQuery());

final trackingZonesProvider = FutureProvider.autoDispose<List<TrackingZone>>(
  (ref) => ref.watch(trackingRepositoryProvider).zones(),
);

final trackingLiveProvider = FutureProvider.autoDispose<PagedResult<TrackedTool>>(
  (ref) => ref.watch(trackingRepositoryProvider).live(ref.watch(trackingQueryProvider)),
);

final locateToolProvider = FutureProvider.autoDispose.family<ToolLocation, int>(
  (ref, toolId) => ref.watch(trackingRepositoryProvider).locate(toolId),
);

final transferHistoryProvider = FutureProvider.autoDispose<List<ToolTransfer>>(
  (ref) => ref.watch(trackingRepositoryProvider).transfers(),
);
