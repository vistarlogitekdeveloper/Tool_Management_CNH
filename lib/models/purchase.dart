import 'json.dart';
import 'user.dart' show NamedRef;

class PurchaseOrderItem {
  const PurchaseOrderItem({
    required this.id,
    required this.toolId,
    required this.toolCode,
    required this.toolName,
    required this.qty,
    this.uom = 'NOS',
    this.receivedQty = 0,
    this.pendingQty = 0,
    this.rate = 0,
    this.taxPercent = 0,
    this.amount = 0,
    this.remarks,
  });

  final int id;
  final int toolId;
  final String toolCode;
  final String toolName;
  final String uom;
  final int qty;
  final int receivedQty;
  final int pendingQty;
  final double rate;
  final double taxPercent;
  final double amount;
  final String? remarks;

  bool get isFullyReceived => receivedQty >= qty;

  factory PurchaseOrderItem.fromJson(Json j) => PurchaseOrderItem(
        id: asInt(j['id']),
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        toolName: str(j['toolName']),
        uom: str(j['uom'], 'NOS'),
        qty: asInt(j['qty']),
        receivedQty: asInt(j['receivedQty']),
        pendingQty: asInt(j['pendingQty']),
        rate: asDouble(j['rate']),
        taxPercent: asDouble(j['taxPercent']),
        amount: asDouble(j['amount']),
        remarks: strOrNull(j['remarks']),
      );
}

class GoodsReceipt {
  const GoodsReceipt({
    required this.id,
    required this.grnNo,
    this.receiptDate,
    this.invoiceNo,
    this.qty = 0,
    this.remarks,
    this.receivedByName,
  });

  final int id;
  final String grnNo;
  final DateTime? receiptDate;
  final String? invoiceNo;
  final int qty;
  final String? remarks;
  final String? receivedByName;

  factory GoodsReceipt.fromJson(Json j) => GoodsReceipt(
        id: asInt(j['id']),
        grnNo: str(j['grnNo']),
        receiptDate: asDate(j['receiptDate']),
        invoiceNo: strOrNull(j['invoiceNo']),
        qty: asInt(j['qty']),
        remarks: strOrNull(j['remarks']),
        receivedByName: strOrNull(j['receivedByName']),
      );
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.poNo,
    required this.vendor,
    this.poDate,
    this.expectedDate,
    this.status = 'PENDING',
    this.currency = 'INR',
    this.subtotal = 0,
    this.taxAmount = 0,
    this.totalValue = 0,
    this.referenceNo,
    this.remarks,
    this.createdByName,
    this.approvedByName,
    this.approvedAt,
    this.itemCount = 0,
    this.totalQty = 0,
    this.receivedQty = 0,
    this.isDelayed = false,
    this.items = const [],
    this.receipts = const [],
    this.createdAt,
    this.grnNo,
  });

  final int id;
  final String poNo;
  final NamedRef vendor;
  final DateTime? poDate;
  final DateTime? expectedDate;
  final String status;
  final String currency;
  final double subtotal;
  final double taxAmount;
  final double totalValue;
  final String? referenceNo;
  final String? remarks;
  final String? createdByName;
  final String? approvedByName;
  final DateTime? approvedAt;
  final int itemCount;
  final int totalQty;
  final int receivedQty;
  final bool isDelayed;
  final List<PurchaseOrderItem> items;
  final List<GoodsReceipt> receipts;
  final DateTime? createdAt;

  /// Present on the response to a receive call.
  final String? grnNo;

  bool get isOpen => status != 'RECEIVED' && status != 'CANCELLED';
  bool get canApprove => status == 'DRAFT' || status == 'PENDING';
  bool get canReceive => const {'APPROVED', 'IN_TRANSIT', 'PARTIALLY_RECEIVED'}.contains(status);
  bool get canMarkInTransit => status == 'APPROVED';

  int get pendingQty => (totalQty - receivedQty).clamp(0, 1 << 30);

  double get receivedPercent => totalQty == 0 ? 0 : (receivedQty / totalQty) * 100;

  factory PurchaseOrder.fromJson(Json j) => PurchaseOrder(
        id: asInt(j['id']),
        poNo: str(j['poNo']),
        vendor: NamedRef.fromJson(asMap(j['vendor'])),
        poDate: asDate(j['poDate']),
        expectedDate: asDate(j['expectedDate']),
        status: str(j['status'], 'PENDING'),
        currency: str(j['currency'], 'INR'),
        subtotal: asDouble(j['subtotal']),
        taxAmount: asDouble(j['taxAmount']),
        totalValue: asDouble(j['totalValue']),
        referenceNo: strOrNull(j['referenceNo']),
        remarks: strOrNull(j['remarks']),
        createdByName: strOrNull(j['createdByName']),
        approvedByName: strOrNull(j['approvedByName']),
        approvedAt: asDate(j['approvedAt']),
        itemCount: asInt(j['itemCount']),
        totalQty: asInt(j['totalQty']),
        receivedQty: asInt(j['receivedQty']),
        isDelayed: asBool(j['isDelayed']),
        items: asList(j['items'], PurchaseOrderItem.fromJson),
        receipts: asList(j['receipts'], GoodsReceipt.fromJson),
        createdAt: asDate(j['createdAt']),
        grnNo: strOrNull(j['grnNo']),
      );

  /// First line's tool name, for the compact grid row.
  String get primaryToolLabel {
    if (items.isEmpty) return itemCount > 0 ? '$itemCount line item(s)' : '—';
    if (items.length == 1) return items.first.toolName;
    return '${items.first.toolName} +${items.length - 1} more';
  }
}

class PurchaseSummary {
  const PurchaseSummary({
    this.total = 0,
    this.pending = 0,
    this.approved = 0,
    this.inTransit = 0,
    this.partiallyReceived = 0,
    this.received = 0,
    this.delayed = 0,
    this.openValue = 0,
    this.ytdValue = 0,
  });

  final int total;
  final int pending;
  final int approved;
  final int inTransit;
  final int partiallyReceived;
  final int received;
  final int delayed;
  final double openValue;
  final double ytdValue;

  factory PurchaseSummary.fromJson(Json j) => PurchaseSummary(
        total: asInt(j['total']),
        pending: asInt(j['pending']),
        approved: asInt(j['approved']),
        inTransit: asInt(j['inTransit']),
        partiallyReceived: asInt(j['partiallyReceived']),
        received: asInt(j['received']),
        delayed: asInt(j['delayed']),
        openValue: asDouble(j['openValue']),
        ytdValue: asDouble(j['ytdValue']),
      );
}

class ReorderLine {
  const ReorderLine({
    required this.toolId,
    required this.toolCode,
    required this.name,
    this.categoryName,
    this.available = 0,
    this.minStock = 0,
    this.suggestedQty = 1,
    this.rate = 0,
    this.lineValue = 0,
    this.openPoCount = 0,
  });

  final int toolId;
  final String toolCode;
  final String name;
  final String? categoryName;
  final int available;
  final int minStock;
  final int suggestedQty;
  final double rate;
  final double lineValue;
  final int openPoCount;

  factory ReorderLine.fromJson(Json j) => ReorderLine(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        categoryName: strOrNull(j['categoryName']),
        available: asInt(j['available']),
        minStock: asInt(j['minStock']),
        suggestedQty: asInt(j['suggestedQty'], 1),
        rate: asDouble(j['rate']),
        lineValue: asDouble(j['lineValue']),
        openPoCount: asInt(j['openPoCount']),
      );
}

/// Low-stock tools grouped by their most recent supplier, ready to become a PO.
class ReorderSuggestion {
  const ReorderSuggestion({
    this.vendorId,
    required this.vendorName,
    this.lines = const [],
    this.estimatedValue = 0,
  });

  final int? vendorId;
  final String vendorName;
  final List<ReorderLine> lines;
  final double estimatedValue;

  factory ReorderSuggestion.fromJson(Json j) => ReorderSuggestion(
        vendorId: asIntOrNull(j['vendorId']),
        vendorName: str(j['vendorName']),
        lines: asList(j['lines'], ReorderLine.fromJson),
        estimatedValue: asDouble(j['estimatedValue']),
      );
}

/// Draft line while composing a new purchase order.
class PoDraftLine {
  PoDraftLine({
    required this.toolId,
    required this.toolCode,
    required this.toolName,
    this.qty = 1,
    this.rate = 0,
    this.taxPercent = 18,
  });

  final int toolId;
  final String toolCode;
  final String toolName;
  int qty;
  double rate;
  double taxPercent;

  double get net => qty * rate;
  double get tax => net * taxPercent / 100;
  double get total => net + tax;

  Json toJson() => {'toolId': toolId, 'qty': qty, 'rate': rate, 'taxPercent': taxPercent};
}
