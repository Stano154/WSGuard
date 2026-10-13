import 'package:flutter/material.dart';

import 'blocker_api.dart';
import 'l10n.dart';

/// Karta jedného pravidla (aplikácia, stránka alebo zoznam).
///
/// Trvalé pravidlo: vypínač + menu (Zablokovať na čas, Odstrániť…).
/// Časové pravidlo: odpočet a "Odblokovať na N min" – nedá sa vypnúť ani odstrániť.
class RuleCard extends StatelessWidget {
  const RuleCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.methodActive,
    required this.unblockMinutes,
    required this.onToggle,
    required this.onRemove,
    required this.onBlockForTime,
    required this.onUnblock,
    this.timerEnd,
    this.pauseEnd,
    this.cancelEnd,
    this.onCancelTimer,
    this.unblocksLeft,
    this.onTap,
    this.extraMenu = const [],
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final RuleStatus status;

  /// Beží spôsob blokovania, ktorý toto pravidlo potrebuje (VPN / prístupnosť)?
  final bool methodActive;
  final DateTime? timerEnd;
  final DateTime? pauseEnd;

  /// Do kedy sa dá práve spustené časové blokovanie zrušiť (null = už nie).
  final DateTime? cancelEnd;
  final VoidCallback? onCancelTimer;

  /// Zostávajúce dočasné odblokovania dnes (null = odblokovanie je vypnuté – "Nikdy").
  final int? unblocksLeft;
  final int unblockMinutes;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;
  final VoidCallback onBlockForTime;
  final VoidCallback onUnblock;
  final VoidCallback? onTap;

  /// Ďalšie položky menu (napr. "Upraviť" pri zozname): (ikona, text, akcia).
  final List<(IconData, String, VoidCallback)> extraMenu;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final allowed = status == RuleStatus.allowed;
    final locked = status.isTimedLock;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
      decoration: BoxDecoration(
        color: allowed ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: allowed
            ? Border.all(color: scheme.outlineVariant)
            : locked
                ? Border.all(color: scheme.primary.withValues(alpha: 0.35))
                : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: allowed ? 0.4 : 1,
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: leading),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: allowed ? scheme.onSurfaceVariant : scheme.onSurface,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                const SizedBox(height: 6),
                _StatusPill(
                  status: status,
                  methodActive: methodActive,
                  timerEnd: timerEnd,
                  pauseEnd: pauseEnd,
                ),
                if (locked && cancelEnd != null && onCancelTimer != null) ...[
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onCancelTimer,
                    style: TextButton.styleFrom(
                      foregroundColor: scheme.error,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.undo_rounded, size: 18),
                    label: Text(
                      s.cancelTimerButton(cancelEnd!.difference(DateTime.now())),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
                if (status == RuleStatus.timed && unblocksLeft != null) ...[
                  const SizedBox(height: 6),
                  _UnblockButton(
                    minutes: unblockMinutes,
                    left: unblocksLeft!,
                    onPressed: onUnblock,
                  ),
                ],
              ],
            ),
          ),
          if (locked)
            Padding(
              padding: const EdgeInsets.only(top: 12, right: 4),
              child: Icon(Icons.lock_clock_rounded, color: scheme.primary),
            )
          else
            Tooltip(
              message: s.toggleTooltip,
              child: Switch(value: !allowed, onChanged: onToggle),
            ),
          PopupMenuButton<VoidCallback>(
            tooltip: s.moreOptions,
            icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
            onSelected: (action) => action(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: onBlockForTime,
                child: _MenuRow(icon: Icons.lock_clock_rounded, text: s.blockForTime),
              ),
              for (final (icon, text, action) in extraMenu)
                PopupMenuItem(value: action, child: _MenuRow(icon: icon, text: text)),
              PopupMenuItem(
                value: onRemove,
                enabled: !locked,
                child: _MenuRow(icon: Icons.delete_outline_rounded, text: s.remove),
              ),
            ],
          ),
        ],
      ),
    );

    final tappable = onTap == null
        ? card
        : Material(
            color: Colors.transparent,
            child: InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card),
          );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      // Časové pravidlo sa nedá odstrániť ani potiahnutím.
      child: locked
          ? tappable
          : Dismissible(
              key: ValueKey('dismiss-$key'),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => onRemove(),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(s.remove,
                        style: TextStyle(
                            color: scheme.onErrorContainer, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
                  ],
                ),
              ),
              child: tappable,
            ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Text(text),
        ],
      );
}

class _UnblockButton extends StatelessWidget {
  const _UnblockButton({required this.minutes, required this.left, required this.onPressed});

  final int minutes;
  final int left;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final exhausted = left == 0;
    return OutlinedButton.icon(
      onPressed: exhausted ? null : onPressed,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.timer_outlined, size: 18),
      label: Text(
        exhausted
            ? s.unblockLimit
            : '${s.unblockFor(minutes)} · ${s.unblocksLeft(left)}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.status,
    required this.methodActive,
    this.timerEnd,
    this.pauseEnd,
  });

  final RuleStatus status;
  final bool methodActive;
  final DateTime? timerEnd;
  final DateTime? pauseEnd;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final green = dark ? const Color(0xFF6DD58C) : const Color(0xFF1B7F3B);
    final amber = dark ? const Color(0xFFFFB95C) : const Color(0xFFB25E00);
    final blue = dark ? const Color(0xFF8AB4F8) : const Color(0xFF1A62C9);
    final now = DateTime.now();

    final (Color color, IconData icon, String text) = switch (status) {
      RuleStatus.allowed => (scheme.onSurfaceVariant, Icons.lock_open_rounded, s.statusAllowed),
      RuleStatus.paused => (
          blue,
          Icons.timer_outlined,
          s.statusPaused((pauseEnd ?? now).difference(now)),
        ),
      RuleStatus.timed when methodActive => (
          green,
          Icons.lock_clock_rounded,
          s.statusTimed((timerEnd ?? now).difference(now)),
        ),
      RuleStatus.permanent when methodActive => (green, Icons.lock_rounded, s.statusBlocked),
      _ => (amber, Icons.pause_circle_outline_rounded, s.statusInactive),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
