import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

import 'wallet_icons.dart';

enum WalletAction { edit, archive, restore, delete }

class WalletCard extends StatelessWidget {
  const WalletCard({
    required this.wallet,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onDelete,
    super.key,
  });

  final Wallet wallet;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Icon(iconForWallet(wallet.iconIdentifier), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          wallet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          wallet.accountType.label,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<WalletAction>(
                    tooltip: 'Actions for ${wallet.name}',
                    onSelected: (WalletAction action) {
                      switch (action) {
                        case WalletAction.edit:
                          onEdit();
                        case WalletAction.archive:
                          onArchive();
                        case WalletAction.restore:
                          onRestore();
                        case WalletAction.delete:
                          onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuEntry<WalletAction>>[
                      const PopupMenuItem<WalletAction>(
                        value: WalletAction.edit,
                        child: _MenuRow(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                        ),
                      ),
                      if (wallet.isArchived)
                        const PopupMenuItem<WalletAction>(
                          value: WalletAction.restore,
                          child: _MenuRow(
                            icon: Icons.unarchive_outlined,
                            label: 'Restore',
                          ),
                        )
                      else
                        const PopupMenuItem<WalletAction>(
                          value: WalletAction.archive,
                          child: _MenuRow(
                            icon: Icons.archive_outlined,
                            label: 'Archive',
                          ),
                        ),
                      if (wallet.isArchived)
                        PopupMenuItem<WalletAction>(
                          value: WalletAction.delete,
                          child: _MenuRow(
                            icon: Icons.delete_outline,
                            label: 'Delete permanently',
                            color: scheme.error,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Text(
                    wallet.balance.format(),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (wallet.isArchived)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Archived',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
