import 'enums.dart';
import 'json.dart';

class UserRole {
  const UserRole({required this.id, required this.code, required this.name});

  final int id;
  final String code;
  final String name;

  factory UserRole.fromJson(Json j) => UserRole(
        id: asInt(j['id']),
        code: str(j['code']),
        name: str(j['name']),
      );

  Json toJson() => {'id': id, 'code': code, 'name': name};
}

class NamedRef {
  const NamedRef({required this.id, required this.name});

  final int id;
  final String name;

  factory NamedRef.fromJson(Json j) => NamedRef(id: asInt(j['id']), name: str(j['name']));

  Json toJson() => {'id': id, 'name': name};
}

/// The signed-in user, plus the permission and module lists that drive every
/// navigation and button-level access decision in the app.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.employeeCode,
    this.department,
    this.mustChangePassword = false,
    this.lastLoginAt,
    this.permissions = const [],
    this.modules = const [],
  });

  final int id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? employeeCode;
  final NamedRef? department;
  final UserRole role;
  final bool mustChangePassword;
  final DateTime? lastLoginAt;
  final List<String> permissions;
  final List<String> modules;

  factory AuthUser.fromJson(Json j) => AuthUser(
        id: asInt(j['id']),
        username: str(j['username']),
        fullName: str(j['fullName']),
        email: strOrNull(j['email']),
        phone: strOrNull(j['phone']),
        employeeCode: strOrNull(j['employeeCode']),
        department: asMapOrNull(j['department']) == null ? null : NamedRef.fromJson(asMap(j['department'])),
        role: UserRole.fromJson(asMap(j['role'])),
        mustChangePassword: asBool(j['mustChangePassword']),
        lastLoginAt: asDate(j['lastLoginAt']),
        permissions: asStringList(j['permissions']),
        modules: asStringList(j['modules']),
      );

  Json toJson() => {
        'id': id,
        'username': username,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'employeeCode': employeeCode,
        'department': department?.toJson(),
        'role': role.toJson(),
        'mustChangePassword': mustChangePassword,
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'permissions': permissions,
        'modules': modules,
      };

  bool can(String permission) => permissions.contains(permission);

  bool canAny(List<String> perms) => perms.any(permissions.contains);

  bool canSee(AppModule module) => modules.contains(module.code);

  bool get isAdmin => role.code == 'ADMIN';

  /// Modules in sidebar order, filtered to this role.
  List<AppModule> get visibleModules =>
      AppModule.values.where((m) => modules.contains(m.code)).toList();

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return username.isEmpty ? '?' : username[0].toUpperCase();
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The token pair plus profile returned by /auth/login and /auth/refresh.
class AuthSession {
  const AuthSession({required this.user, required this.accessToken, required this.refreshToken});

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Json j) => AuthSession(
        user: AuthUser.fromJson(asMap(j['user'])),
        accessToken: str(j['accessToken']),
        refreshToken: str(j['refreshToken']),
      );
}

/// A managed user row on the administration screen.
class ManagedUser {
  const ManagedUser({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    this.email,
    this.phone,
    this.employeeCode,
    this.department,
    this.isActive = true,
    this.isLocked = false,
    this.mustChangePassword = false,
    this.lastLoginAt,
  });

  final int id;
  final String username;
  final String fullName;
  final String? email;
  final String? phone;
  final String? employeeCode;
  final NamedRef? department;
  final UserRole role;
  final bool isActive;
  final bool isLocked;
  final bool mustChangePassword;
  final DateTime? lastLoginAt;

  factory ManagedUser.fromJson(Json j) => ManagedUser(
        id: asInt(j['id']),
        username: str(j['username']),
        fullName: str(j['fullName']),
        email: strOrNull(j['email']),
        phone: strOrNull(j['phone']),
        employeeCode: strOrNull(j['employeeCode']),
        department: asMapOrNull(j['department']) == null ? null : NamedRef.fromJson(asMap(j['department'])),
        role: UserRole.fromJson(asMap(j['role'])),
        isActive: asBool(j['isActive'], true),
        isLocked: asBool(j['isLocked']),
        mustChangePassword: asBool(j['mustChangePassword']),
        lastLoginAt: asDate(j['lastLoginAt']),
      );
}

class RoleDefinition {
  const RoleDefinition({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    this.permissions = const [],
    this.modules = const [],
  });

  final int id;
  final String code;
  final String name;
  final String? description;
  final List<String> permissions;
  final List<String> modules;

  factory RoleDefinition.fromJson(Json j) => RoleDefinition(
        id: asInt(j['id']),
        code: str(j['code']),
        name: str(j['name']),
        description: strOrNull(j['description']),
        permissions: asStringList(j['permissions']),
        modules: asStringList(j['modules']),
      );
}
