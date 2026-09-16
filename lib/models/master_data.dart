import 'dart:ui';

import '../core/theme/app_colors.dart';
import 'json.dart';

class ToolCategory {
  const ToolCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.colourHex,
    this.description,
    this.isActive = true,
    this.toolCount,
  });

  final int id;
  final String code;
  final String name;
  final String colourHex;
  final String? description;
  final bool isActive;
  final int? toolCount;

  Color get colour => AppColors.fromHex(colourHex);

  factory ToolCategory.fromJson(Json j) => ToolCategory(
        id: asInt(j['id']),
        code: str(j['code']),
        name: str(j['name']),
        colourHex: str(j['colour'], '#64748b'),
        description: strOrNull(j['description']),
        isActive: asBool(j['isActive'], true),
        toolCount: asIntOrNull(j['toolCount']),
      );
}

class PlantLocation {
  const PlantLocation({
    required this.id,
    required this.code,
    required this.name,
    this.shop,
    this.line,
    this.station,
    this.parentId,
    this.isStore = false,
    this.isActive = true,
    this.toolCount,
  });

  final int id;
  final String code;
  final String name;
  final String? shop;
  final String? line;
  final String? station;
  final int? parentId;
  final bool isStore;
  final bool isActive;
  final int? toolCount;

  factory PlantLocation.fromJson(Json j) => PlantLocation(
        id: asInt(j['id']),
        code: str(j['code']),
        name: str(j['name']),
        shop: strOrNull(j['shop']),
        line: strOrNull(j['line']),
        station: strOrNull(j['station']),
        parentId: asIntOrNull(j['parentId']),
        isStore: asBool(j['isStore']),
        isActive: asBool(j['isActive'], true),
        toolCount: asIntOrNull(j['toolCount']),
      );

  /// 'Machine Shop · Line A · St-03'
  String get path => [shop, line, station].where((p) => p != null && p.isNotEmpty).join(' · ');
}

class Department {
  const Department({
    required this.id,
    required this.code,
    required this.name,
    this.costCentre,
    this.isActive = true,
    this.employeeCount,
  });

  final int id;
  final String code;
  final String name;
  final String? costCentre;
  final bool isActive;
  final int? employeeCount;

  factory Department.fromJson(Json j) => Department(
        id: asInt(j['id']),
        code: str(j['code']),
        name: str(j['name']),
        costCentre: strOrNull(j['costCentre']),
        isActive: asBool(j['isActive'], true),
        employeeCount: asIntOrNull(j['employeeCount']),
      );
}

class Employee {
  const Employee({
    required this.id,
    required this.empCode,
    required this.name,
    this.departmentId,
    this.departmentName,
    this.defaultLocationId,
    this.defaultLocationName,
    this.designation,
    this.shift,
    this.phone,
    this.isActive = true,
    this.openIssues,
  });

  final int id;
  final String empCode;
  final String name;
  final int? departmentId;
  final String? departmentName;
  final int? defaultLocationId;
  final String? defaultLocationName;
  final String? designation;
  final String? shift;
  final String? phone;
  final bool isActive;
  final int? openIssues;

  factory Employee.fromJson(Json j) => Employee(
        id: asInt(j['id']),
        empCode: str(j['empCode']),
        name: str(j['name']),
        departmentId: asIntOrNull(j['departmentId']),
        departmentName: strOrNull(j['departmentName']),
        defaultLocationId: asIntOrNull(j['defaultLocationId']),
        defaultLocationName: strOrNull(j['defaultLocationName']),
        designation: strOrNull(j['designation']),
        shift: strOrNull(j['shift']),
        phone: strOrNull(j['phone']),
        isActive: asBool(j['isActive'], true),
        openIssues: asIntOrNull(j['openIssues']),
      );

  String get label => '$name · $empCode';

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class Vendor {
  const Vendor({
    required this.id,
    required this.code,
    required this.name,
    this.isSupplier = true,
    this.isRepairVendor = false,
    this.isCalibrationLab = false,
    this.contactPerson,
    this.phone,
    this.email,
    this.address,
    this.gstNo,
    this.paymentTerms,
    this.leadTimeDays,
    this.isActive = true,
    this.poCount,
  });

  final int id;
  final String code;
  final String name;
  final bool isSupplier;
  final bool isRepairVendor;
  final bool isCalibrationLab;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? address;
  final String? gstNo;
  final String? paymentTerms;
  final int? leadTimeDays;
  final bool isActive;
  final int? poCount;

  factory Vendor.fromJson(Json j) => Vendor(
        id: asInt(j['id']),
        code: str(j['code']),
        name: str(j['name']),
        isSupplier: asBool(j['isSupplier'], true),
        isRepairVendor: asBool(j['isRepairVendor']),
        isCalibrationLab: asBool(j['isCalibrationLab']),
        contactPerson: strOrNull(j['contactPerson']),
        phone: strOrNull(j['phone']),
        email: strOrNull(j['email']),
        address: strOrNull(j['address']),
        gstNo: strOrNull(j['gstNo']),
        paymentTerms: strOrNull(j['paymentTerms']),
        leadTimeDays: asIntOrNull(j['leadTimeDays']),
        isActive: asBool(j['isActive'], true),
        poCount: asIntOrNull(j['poCount']),
      );

  List<String> get roles => [
        if (isSupplier) 'Supplier',
        if (isRepairVendor) 'Repair',
        if (isCalibrationLab) 'Calibration lab',
      ];
}

/// Every dropdown the app needs, fetched once at sign-in.
class MasterBootstrap {
  const MasterBootstrap({
    this.categories = const [],
    this.locations = const [],
    this.departments = const [],
    this.employees = const [],
    this.vendors = const [],
    this.shops = const [],
  });

  final List<ToolCategory> categories;
  final List<PlantLocation> locations;
  final List<Department> departments;
  final List<Employee> employees;
  final List<Vendor> vendors;
  final List<String> shops;

  factory MasterBootstrap.fromJson(Json j) => MasterBootstrap(
        categories: asList(j['categories'], ToolCategory.fromJson),
        locations: asList(j['locations'], PlantLocation.fromJson),
        departments: asList(j['departments'], Department.fromJson),
        employees: asList(j['employees'], Employee.fromJson),
        vendors: asList(j['vendors'], Vendor.fromJson),
        shops: asStringList(j['shops']),
      );

  ToolCategory? category(int? id) =>
      id == null ? null : categories.where((c) => c.id == id).firstOrNull;

  PlantLocation? location(int? id) =>
      id == null ? null : locations.where((l) => l.id == id).firstOrNull;

  Employee? employee(int? id) => id == null ? null : employees.where((e) => e.id == id).firstOrNull;

  Vendor? vendor(int? id) => id == null ? null : vendors.where((v) => v.id == id).firstOrNull;

  List<Vendor> get suppliers => vendors.where((v) => v.isSupplier).toList();
  List<Vendor> get repairVendors => vendors.where((v) => v.isRepairVendor).toList();
  List<Vendor> get calibrationLabs => vendors.where((v) => v.isCalibrationLab).toList();
  List<PlantLocation> get stores => locations.where((l) => l.isStore).toList();

  bool get isEmpty => categories.isEmpty && locations.isEmpty && employees.isEmpty;
}

class AppSetting {
  const AppSetting({
    required this.key,
    required this.value,
    required this.dataType,
    required this.category,
    this.label,
    this.description,
    this.updatedAt,
    this.updatedByName,
  });

  final String key;
  final Object? value;
  final String dataType;
  final String category;
  final String? label;
  final String? description;
  final DateTime? updatedAt;
  final String? updatedByName;

  factory AppSetting.fromJson(Json j) => AppSetting(
        key: str(j['key']),
        value: j['value'],
        dataType: str(j['dataType'], 'string'),
        category: str(j['category'], 'general'),
        label: strOrNull(j['label']),
        description: strOrNull(j['description']),
        updatedAt: asDate(j['updatedAt']),
        updatedByName: strOrNull(j['updatedByName']),
      );

  bool get asBoolValue => asBool(value);
  num get asNumValue => asDouble(value);
  String get displayValue => value?.toString() ?? '—';
}
