import 'json.dart';

/// A row on the Inventory Management grid.
class InventoryRow {
  const InventoryRow({
    required this.toolId,
    required this.toolCode,
    required this.name,
    this.categoryName,
    this.categoryColour,
    this.locationName,
    this.uom = 'NOS',
    this.unitCost = 0,
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
    this.stockPercent = 0,
    this.isLowStock = false,
    this.inventoryValue = 0,
  });

  final int toolId;
  final String toolCode;
  final String name;
  final String? categoryName;
  final String? categoryColour;
  final String? locationName;
  final String uom;
  final double unitCost;
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
  final double stockPercent;
  final bool isLowStock;
  final double inventoryValue;

  String get status => isLowStock ? 'LOW' : 'OK';

  factory InventoryRow.fromJson(Json j) => InventoryRow(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        categoryName: strOrNull(j['categoryName']),
        categoryColour: strOrNull(j['categoryColour']),
        locationName: strOrNull(j['locationName']),
        uom: str(j['uom'], 'NOS'),
        unitCost: asDouble(j['unitCost']),
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
        stockPercent: asDouble(j['stockPercent']),
        isLowStock: asBool(j['isLowStock']),
        inventoryValue: asDouble(j['inventoryValue']),
      );
}

class InventorySummary {
  const InventorySummary({
    this.toolCount = 0,
    this.totalQty = 0,
    this.availableQty = 0,
    this.issuedQty = 0,
    this.reservedQty = 0,
    this.repairQty = 0,
    this.scrapQty = 0,
    this.damagedQty = 0,
    this.lostQty = 0,
    this.lowStockCount = 0,
    this.inventoryValue = 0,
  });

  final int toolCount;
  final int totalQty;
  final int availableQty;
  final int issuedQty;
  final int reservedQty;
  final int repairQty;
  final int scrapQty;
  final int damagedQty;
  final int lostQty;
  final int lowStockCount;
  final double inventoryValue;

  factory InventorySummary.fromJson(Json j) => InventorySummary(
        toolCount: asInt(j['toolCount']),
        totalQty: asInt(j['totalQty']),
        availableQty: asInt(j['availableQty']),
        issuedQty: asInt(j['issuedQty']),
        reservedQty: asInt(j['reservedQty']),
        repairQty: asInt(j['repairQty']),
        scrapQty: asInt(j['scrapQty']),
        damagedQty: asInt(j['damagedQty']),
        lostQty: asInt(j['lostQty']),
        lowStockCount: asInt(j['lowStockCount']),
        inventoryValue: asDouble(j['inventoryValue']),
      );
}

/// A tool below its minimum, with the order quantity the system suggests.
class LowStockItem {
  const LowStockItem({
    required this.toolId,
    required this.toolCode,
    required this.name,
    this.categoryName,
    this.available = 0,
    this.total = 0,
    this.minStock = 0,
    this.reorderLevel = 0,
    this.shortfall = 0,
    this.suggestedOrderQty = 0,
    this.unitCost = 0,
    this.estimatedCost = 0,
    this.openPoCount = 0,
    this.stockPercent = 0,
  });

  final int toolId;
  final String toolCode;
  final String name;
  final String? categoryName;
  final int available;
  final int total;
  final int minStock;
  final int reorderLevel;
  final int shortfall;
  final int suggestedOrderQty;
  final double unitCost;
  final double estimatedCost;
  final int openPoCount;
  final double stockPercent;

  bool get hasOpenPo => openPoCount > 0;

  factory LowStockItem.fromJson(Json j) => LowStockItem(
        toolId: asInt(j['toolId']),
        toolCode: str(j['toolCode']),
        name: str(j['name']),
        categoryName: strOrNull(j['categoryName']),
        available: asInt(j['available']),
        total: asInt(j['total']),
        minStock: asInt(j['minStock']),
        reorderLevel: asInt(j['reorderLevel']),
        shortfall: asInt(j['shortfall']),
        suggestedOrderQty: asInt(j['suggestedOrderQty']),
        unitCost: asDouble(j['unitCost']),
        estimatedCost: asDouble(j['estimatedCost']),
        openPoCount: asInt(j['openPoCount']),
        stockPercent: asDouble(j['stockPercent']),
      );
}

class ValuationRow {
  const ValuationRow({
    required this.categoryName,
    this.colour,
    this.toolCount = 0,
    this.totalQty = 0,
    this.availableQty = 0,
    this.totalValue = 0,
    this.availableValue = 0,
    this.scrappedValue = 0,
    this.sharePercent = 0,
  });

  final String categoryName;
  final String? colour;
  final int toolCount;
  final int totalQty;
  final int availableQty;
  final double totalValue;
  final double availableValue;
  final double scrappedValue;
  final int sharePercent;

  factory ValuationRow.fromJson(Json j) => ValuationRow(
        categoryName: str(j['categoryName']),
        colour: strOrNull(j['colour']),
        toolCount: asInt(j['toolCount']),
        totalQty: asInt(j['totalQty']),
        availableQty: asInt(j['availableQty']),
        totalValue: asDouble(j['totalValue']),
        availableValue: asDouble(j['availableValue']),
        scrappedValue: asDouble(j['scrappedValue']),
        sharePercent: asInt(j['sharePercent']),
      );
}

class Valuation {
  const Valuation({this.byCategory = const [], this.grandTotal = 0});

  final List<ValuationRow> byCategory;
  final double grandTotal;

  factory Valuation.fromJson(Json j) => Valuation(
        byCategory: asList(j['byCategory'], ValuationRow.fromJson),
        grandTotal: asDouble(j['grandTotal']),
      );
}
