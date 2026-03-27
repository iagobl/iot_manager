import 'package:flutter/material.dart';
import 'package:iot_manager/core/error/error_mapper.dart';
import 'package:iot_manager/features/devices/data/datasources/devices_remote_datasource.dart';
import 'package:iot_manager/features/devices/presentation/controllers/device_share_controller.dart';

class DeviceShareSection extends StatefulWidget {
  const DeviceShareSection({
    super.key,
    required this.deviceId,
    required this.deviceName,
    required this.remoteDatasource,
  });

  final String deviceId;
  final String deviceName;
  final DevicesRemoteDatasource remoteDatasource;

  @override
  State<DeviceShareSection> createState() => DeviceShareSectionState();
}

class DeviceShareSectionState extends State<DeviceShareSection> {
  late final DeviceShareController ctrl;
  final TextEditingController emailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl = DeviceShareController(
      deviceId: widget.deviceId,
      deviceName: widget.deviceName,
      remoteDatasource: widget.remoteDatasource,
    )..addListener(onControllerChanged);
    ctrl.load();
  }

  void onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ctrl.removeListener(onControllerChanged);
    ctrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  void showSnack(String text) {
    if (!mounted || text.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> handleInviteByEmail() async {
    try {
      final message = await ctrl.inviteByEmail(emailCtrl.text);
      emailCtrl.clear();
      showSnack(message);
    } catch (error) {
      showSnack(
        ctrl.error ?? ErrorMapper.mapFailure(error).message,
      );
    }
  }

  Future<void> handleRevoke(String shareId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: const Text('Ese usuario dejará de poder usar el dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revocar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await ctrl.revokeShare(shareId);
      showSnack(message);
    } catch (error) {
      showSnack(ctrl.error ?? ErrorMapper.mapFailure(error).message,);
    }
  }

  Future<void> _handleLeave(String shareId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar dispositivo compartido'),
        content: const Text(
          'Este dispositivo dejará de aparecer en tu cuenta y perderás el acceso.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final message = await ctrl.leaveSharedDevice(shareId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating,),
      );

      Navigator.of(context).maybePop();
    } catch (error) {
      showSnack(ctrl.error ?? ErrorMapper.mapFailure(error).message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (ctrl.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (ctrl.error != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: cs.errorContainer.withValues(alpha: 0.7),
        ),
        child: Text(
          ctrl.error!,
          style: TextStyle(color: cs.onErrorContainer),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Text('Compartir dispositivo',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(ctrl.isOwner
              ? 'Puedes invitar usuarios registrados por correo para compartir este dispositivo.'
              : 'Este dispositivo fue compartido contigo. Puedes dejar de tener acceso cuando quieras.',
          style: textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant,),
        ),
        const SizedBox(height: 18),
        if (ctrl.isOwner) ...[
          InviteCard(
            emailController: emailCtrl,
            loading: ctrl.invitingByEmail,
            onInvite: handleInviteByEmail,
          ),
          const SizedBox(height: 20),
        ] else ...[
          const ReadOnlySharedCard(),
          const SizedBox(height: 20),
        ],
        Text(ctrl.isOwner ? 'Usuarios e invitaciones' : 'Acceso compartido',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        if (ctrl.entries.isEmpty)
          EmptyCard(text: ctrl.isOwner
                ? 'Todavía no has compartido este dispositivo.'
                : 'Ya no tienes acceso compartido a este dispositivo.',
          )
        else
          ...ctrl.entries.map(
                (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ShareEntryCard(
                entry: entry,
                isOwner: ctrl.isOwner,
                busy: ctrl.revoking || ctrl.leaving,
                onRevoke: () => handleRevoke(entry.id),
                onLeave: () => _handleLeave(entry.id),
              ),
            ),
          ),
      ],
    );
  }
}

class InviteCard extends StatelessWidget {
  const InviteCard({super.key,
    required this.emailController,
    required this.loading,
    required this.onInvite,
  });

  final TextEditingController emailController;
  final bool loading;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invitar por correo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text('Escribe el correo de un usuario registrado para enviarle una invitación interna.',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Correo electrónico',
              hintText: 'usuario@correo.com',
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: loading ? null : onInvite,
            icon: loading
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
                : const Icon(Icons.person_add_alt_1_outlined),
            label: const Text('Enviar invitación'),
          ),
        ],
      ),
    );
  }
}

class ReadOnlySharedCard extends StatelessWidget {
  const ReadOnlySharedCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cs.primary.withValues(alpha: 0.07),
        border: Border.all(
          color: cs.primary.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.people_alt_outlined,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Puedes usar el dispositivo normalmente, pero también puedes eliminar este acceso compartido desde aquí.',
              style: TextStyle(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        text,
        style: TextStyle(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class ShareEntryCard extends StatelessWidget {
  const ShareEntryCard({super.key,
    required this.entry,
    required this.isOwner,
    required this.busy,
    required this.onRevoke,
    required this.onLeave,
  });

  final DeviceShareEntry entry;
  final bool isOwner;
  final bool busy;
  final VoidCallback onRevoke;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final statusColor = entry.isAccepted
        ? cs.primary
        : entry.isRevoked || entry.isRejected
        ? cs.error
        : cs.tertiary;

    final statusLabel = entry.isAccepted
        ? 'Aceptado'
        : entry.isRevoked
        ? 'Revocado'
        : entry.isRejected
        ? 'Rechazado'
        : 'Pendiente';

    final displayName = resolveDisplayName(entry);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cs.surface,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 6),
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.primary.withValues(alpha: 0.10),
                ),
                child: Icon(
                  Icons.person_outline_rounded,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              StatusChip(label: statusLabel, color: statusColor,),
            ],
          ),
          if (entry.isAccepted) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: isOwner
                  ? OutlinedButton.icon(
                onPressed: busy ? null : onRevoke,
                icon: const Icon(Icons.person_remove_outlined, size: 18),
                label: const Text('Revocar acceso'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              )
                  : OutlinedButton.icon(
                onPressed: busy ? null : onLeave,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Eliminar acceso'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String resolveDisplayName(DeviceShareEntry entry) {
    final raw = (entry.sharedWithDisplayName ?? '').trim();

    if (raw.isEmpty) return 'Usuario';

    if (raw.contains('@')) {
      final beforeAt = raw.split('@').first.trim();
      if (beforeAt.isNotEmpty) return beforeAt;
      return 'Usuario';
    }

    return raw;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key,
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}