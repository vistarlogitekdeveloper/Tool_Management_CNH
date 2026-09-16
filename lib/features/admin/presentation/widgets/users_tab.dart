import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/feedback.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/async_view.dart';
import '../../../../core/widgets/cards.dart';
import '../../../../core/widgets/data_grid.dart';
import '../../../../core/widgets/form_fields.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../../models/user.dart';
import '../../../shell/data/masters_repository.dart';
import '../../data/admin_repository.dart';

/// User administration — create accounts, change roles, reset passwords and
/// unlock accounts locked out by failed sign-ins.
class UsersTab extends ConsumerWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final users = ref.watch(usersListProvider);
    final roles = ref.watch(rolesProvider).valueOrNull ?? const [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionCard(
            title: 'System users',
            subtitle: 'Every issue, return, calibration and approval is stamped with a name',
            trailing: FilledButton.icon(
              onPressed: () => _showUserDialog(context, ref, roles: roles),
              icon: const Icon(Icons.person_add_alt_rounded, size: 16),
              label: const Text('Add user'),
            ),
            padding: EdgeInsets.zero,
            child: AsyncView<List<ManagedUser>>(
              value: users,
              onRetry: () => ref.invalidate(usersListProvider),
              loading: const GridSkeleton(),
              data: (list) => DataGrid<ManagedUser>(
                rows: list,
                minWidth: 900,
                emptyMessage: 'No users yet.',
                emptyIcon: Icons.people_outline_rounded,
                mobileCardBuilder: (row) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        InitialsAvatar(Fmt.initials(row.fullName), size: 30),
                        const SizedBox(width: Insets.md),
                        Expanded(
                          child: TwoLineCell(primary: row.fullName, secondary: row.username),
                        ),
                        StatusChip(row.isActive ? 'ACTIVE' : 'INACTIVE', dense: true),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${row.role.name}${row.department != null ? ' · ${row.department!.name}' : ''}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
                columns: [
                  GridColumn<ManagedUser>(
                    label: 'Name',
                    flex: 3,
                    cell: (row) => TwoLineCell(
                      primary: row.fullName,
                      secondary: row.username,
                      leading: InitialsAvatar(Fmt.initials(row.fullName), size: 30),
                    ),
                  ),
                  GridColumn<ManagedUser>(
                    label: 'Role',
                    width: 168,
                    cell: (row) => StatusChip(
                      row.role.code,
                      label: row.role.name,
                      dense: true,
                      palette: StatusPalette.blue,
                    ),
                  ),
                  GridColumn<ManagedUser>(
                    label: 'Department',
                    flex: 2,
                    cell: (row) => Text(
                      row.department?.name ?? '—',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ),
                  GridColumn<ManagedUser>(
                    label: 'Last sign-in',
                    width: 132,
                    cell: (row) => Text(
                      row.lastLoginAt == null ? 'Never' : Fmt.ago(row.lastLoginAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  GridColumn<ManagedUser>(
                    label: 'Status',
                    width: 132,
                    cell: (row) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StatusChip(row.isActive ? 'ACTIVE' : 'INACTIVE', dense: true),
                        if (row.isLocked) ...[
                          const SizedBox(width: 5),
                          const Tooltip(
                            message: 'Locked after failed sign-in attempts',
                            child: Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.red),
                          ),
                        ],
                      ],
                    ),
                  ),
                  GridColumn<ManagedUser>(
                    label: '',
                    width: 128,
                    align: Alignment.centerRight,
                    cell: (row) => PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz_rounded, size: 19),
                      tooltip: 'Actions',
                      position: PopupMenuPosition.under,
                      onSelected: (action) => _handleAction(context, ref, row, action, roles),
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', height: 40, child: Text('Edit user')),
                        const PopupMenuItem(
                            value: 'password', height: 40, child: Text('Reset password')),
                        if (row.isLocked)
                          const PopupMenuItem(
                              value: 'unlock', height: 40, child: Text('Unlock account')),
                        PopupMenuItem(
                          value: 'toggle',
                          height: 40,
                          child: Text(row.isActive ? 'Deactivate' : 'Reactivate'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: Insets.lg),
          _RolesCard(roles: roles),
        ],
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ManagedUser user,
    String action,
    List<RoleDefinition> roles,
  ) async {
    final repo = ref.read(adminRepositoryProvider);

    switch (action) {
      case 'edit':
        await _showUserDialog(context, ref, roles: roles, existing: user);
      case 'password':
        final controller = TextEditingController();
        final ok = await confirm(
          context,
          title: 'Reset password for ${user.username}',
          message: 'The user will be required to set a new password at their next sign-in, '
              'and every existing session is revoked.',
          confirmLabel: 'Reset password',
          extra: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13),
            decoration: const InputDecoration(labelText: 'Temporary password', isDense: true),
          ),
        );
        if (ok && context.mounted) {
          if (controller.text.trim().length < 8) {
            context.toast('The temporary password must be at least 8 characters',
                kind: ToastKind.warning);
          } else {
            await runWithProgress(
              context,
              () => repo.resetPassword(user.id, controller.text.trim()),
              successMessage: 'Password reset for ${user.username}',
            );
            ref.invalidate(usersListProvider);
          }
        }
        controller.dispose();
      case 'unlock':
        await runWithProgress(
          context,
          () => repo.unlock(user.id),
          successMessage: '${user.username} unlocked',
        );
        ref.invalidate(usersListProvider);
      case 'toggle':
        await runWithProgress(
          context,
          () => repo.updateUser(user.id, {'isActive': !user.isActive}),
          successMessage: user.isActive
              ? '${user.username} deactivated'
              : '${user.username} reactivated',
        );
        ref.invalidate(usersListProvider);
    }
  }

  Future<void> _showUserDialog(
    BuildContext context,
    WidgetRef ref, {
    required List<RoleDefinition> roles,
    ManagedUser? existing,
  }) async {
    final nameController = TextEditingController(text: existing?.fullName ?? '');
    final usernameController = TextEditingController(text: existing?.username ?? '');
    final emailController = TextEditingController(text: existing?.email ?? '');
    final empCodeController = TextEditingController(text: existing?.employeeCode ?? '');
    final passwordController = TextEditingController();
    var roleId = existing?.role.id ?? (roles.isNotEmpty ? roles.first.id : null);
    int? departmentId = existing?.department?.id;

    final departments = ref.read(masterBootstrapProvider).valueOrNull?.departments ?? const [];

    final saved = await showAppDialog<bool>(
      context,
      StatefulBuilder(
        builder: (context, setState) => AppDialog(
          title: existing == null ? 'Add User' : 'Edit User',
          subtitle: existing?.username,
          icon: Icons.person_outline_rounded,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
            ),
            FilledButton(
              onPressed: () async {
                if (nameController.text.trim().length < 2 || roleId == null) {
                  context.toast('Enter a name and pick a role', kind: ToastKind.warning);
                  return;
                }
                if (existing == null && passwordController.text.length < 8) {
                  context.toast('The initial password must be at least 8 characters',
                      kind: ToastKind.warning);
                  return;
                }

                final payload = <String, dynamic>{
                  'fullName': nameController.text.trim(),
                  'email': emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                  'employeeCode':
                      empCodeController.text.trim().isEmpty ? null : empCodeController.text.trim(),
                  'roleId': roleId,
                  'departmentId': departmentId,
                  if (existing == null) ...{
                    'username': usernameController.text.trim(),
                    'password': passwordController.text,
                    'mustChangePassword': true,
                  },
                };

                final result = await runWithProgress(
                  context,
                  () => existing == null
                      ? ref.read(adminRepositoryProvider).createUser(payload)
                      : ref.read(adminRepositoryProvider).updateUser(existing.id, payload),
                  successMessage: existing == null ? 'User created' : 'User updated',
                );
                if (result != null && context.mounted) Navigator.of(context).pop(true);
              },
              child: Text(existing == null ? 'Create user' : 'Save changes'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              FieldRow(
                children: [
                  LabeledField(
                    label: 'Full name',
                    required: true,
                    child: AppTextField(controller: nameController, hintText: 'e.g. Rahul Kulkarni'),
                  ),
                  LabeledField(
                    label: 'Username',
                    required: existing == null,
                    child: AppTextField(
                      controller: usernameController,
                      hintText: 'e.g. rahul.k',
                      enabled: existing == null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              FieldRow(
                children: [
                  LabeledField(
                    label: 'Email',
                    child: AppTextField(
                      controller: emailController,
                      hintText: 'name@cnh.local',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                  LabeledField(
                    label: 'Employee code',
                    child: AppTextField(controller: empCodeController, hintText: 'e.g. EMP-1009'),
                  ),
                ],
              ),
              const SizedBox(height: Insets.lg),
              FieldRow(
                children: [
                  LabeledField(
                    label: 'Role',
                    required: true,
                    hint: 'The role decides which modules appear in the sidebar',
                    child: AppDropdown<int>(
                      value: roleId,
                      items: [
                        for (final role in roles)
                          DropdownMenuItem(value: role.id, child: Text(role.name)),
                      ],
                      onChanged: (v) => setState(() => roleId = v),
                    ),
                  ),
                  LabeledField(
                    label: 'Department',
                    child: AppDropdown<int>(
                      value: departmentId,
                      hint: 'Optional',
                      items: [
                        for (final d in departments)
                          DropdownMenuItem(value: d.id, child: Text(d.name)),
                      ],
                      onChanged: (v) => setState(() => departmentId = v),
                    ),
                  ),
                ],
              ),
              if (existing == null) ...[
                const SizedBox(height: Insets.lg),
                LabeledField(
                  label: 'Initial password',
                  required: true,
                  hint: 'The user must change it at their first sign-in',
                  child: AppTextField(
                    controller: passwordController,
                    hintText: 'At least 8 characters',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    for (final c in [
      nameController, usernameController, emailController, empCodeController, passwordController,
    ]) {
      c.dispose();
    }

    if (saved ?? false) ref.invalidate(usersListProvider);
  }
}

class _RolesCard extends StatelessWidget {
  const _RolesCard({required this.roles});

  final List<RoleDefinition> roles;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Role profiles',
        subtitle: 'Which modules and actions each role can reach',
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (final role in roles)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: Insets.md),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.line2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            role.name,
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Text(
                          '${role.modules.length} module(s) · ${role.permissions.length} permission(s)',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                    if (role.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        role.description!,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
                      ),
                    ],
                    const SizedBox(height: Insets.sm),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final module in role.modules)
                          StatusChip(
                            module,
                            label: AppModuleLabel.of(module),
                            dense: true,
                            palette: StatusPalette.slate,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
}

/// Module code -> human label, without importing the whole enum machinery.
abstract final class AppModuleLabel {
  static String of(String code) => switch (code) {
        'dashboard' => 'Dashboard',
        'tool_master' => 'Tool Master',
        'inventory' => 'Inventory',
        'issue_return' => 'Issue & Return',
        'tracking' => 'Tracking',
        'calibration' => 'Calibration',
        'repair_scrap' => 'Repair & Scrap',
        'purchase' => 'Purchase',
        'reports' => 'Reports',
        'admin' => 'Administration',
        _ => code,
      };
}
