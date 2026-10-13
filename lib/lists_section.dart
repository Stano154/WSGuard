import 'package:flutter/material.dart';

import 'blocker_api.dart';
import 'l10n.dart';
import 'rule_card.dart';

/// Sekcia "Zoznamy" – skupiny stránok a aplikácií, ktoré sa blokujú naraz.
class ListsSection extends StatelessWidget {
  const ListsSection({
    super.key,
    required this.state,
    required this.onNew,
    required this.onEdit,
    required this.onToggle,
    required this.onRemove,
    required this.onTimer,
    required this.onUnblock,
    required this.onCancelTimer,
  });

  final BlockerState state;
  final VoidCallback onNew;
  final ValueChanged<BlockList> onEdit;
  final void Function(BlockList list, bool blocked) onToggle;
  final ValueChanged<BlockList> onRemove;
  final void Function(String key, String name) onTimer;
  final void Function(String key, String name) onUnblock;

  /// Zrušiť časové blokovanie do 10 min od spustenia: (kľúč, názov).
  final void Function(String key, String name) onCancelTimer;

  /// Beží všetko, čo zoznam potrebuje? (aplikácie -> prístupnosť, stránky -> VPN alebo prístupnosť)
  bool _methodActive(BlockList l) =>
      (l.apps.isEmpty || state.accessibilityActive) &&
      (l.sites.isEmpty || state.vpnRunning || state.accessibilityActive);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(s.lists,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            TextButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add_rounded),
              label: Text(s.newList),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.lists.isEmpty)
          InkWell(
            onTap: onNew,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.playlist_add_rounded, color: scheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.noLists, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(s.listsHint,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (final l in state.lists)
            RuleCard(
              key: ValueKey(listKey(l.id)),
              leading: Container(
                width: 48,
                height: 48,
                color: scheme.secondaryContainer,
                alignment: Alignment.center,
                child: Text(l.emoji, style: const TextStyle(fontSize: 24)),
              ),
              title: l.name,
              subtitle: s.listSummary(l.apps.length, l.sites.length),
              status: state.listStatus(l.id),
              methodActive: _methodActive(l),
              timerEnd: state.timerEnd(listKey(l.id)),
              pauseEnd: state.pauseEnd(listKey(l.id)),
              cancelEnd: state.cancelEnd(listKey(l.id)),
              onCancelTimer: () => onCancelTimer(listKey(l.id), l.name),
              unblocksLeft: state.unblockAllowed ? state.unblocksLeft(listKey(l.id)) : null,
              unblockMinutes: state.unblockMinutes,
              onTap: () => onEdit(l),
              onToggle: (v) => onToggle(l, v),
              onRemove: () => onRemove(l),
              onBlockForTime: () => onTimer(listKey(l.id), l.name),
              onUnblock: () => onUnblock(listKey(l.id), l.name),
              extraMenu: [(Icons.edit_rounded, s.edit, () => onEdit(l))],
            ),
      ],
    );
  }
}
