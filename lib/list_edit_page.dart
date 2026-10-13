import 'package:flutter/material.dart';

import 'add_site_sheet.dart';
import 'blocked_list.dart';
import 'blocker_api.dart';
import 'known_services.dart';
import 'l10n.dart';

/// Vytvorenie alebo úprava zoznamu. Vráti uložený zoznam cez Navigator.pop.
class ListEditPage extends StatefulWidget {
  const ListEditPage({
    super.key,
    this.initial,
    required this.locked,
    required this.installedApps,
  });

  /// null = nový zoznam.
  final BlockList? initial;

  /// Zoznam má bežiace časové blokovanie – položky sa dajú iba pridávať.
  final bool locked;
  final Future<List<InstalledApp>> installedApps;

  @override
  State<ListEditPage> createState() => _ListEditPageState();
}

class _ListEditPageState extends State<ListEditPage> {
  static const _emojis = ['📱', '💬', '🎬', '🎮', '🛒', '📰', '⭐', '📋'];

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _emoji = widget.initial?.emoji ?? '📱';
  late List<String> _sites = [...?widget.initial?.sites];
  late List<String> _apps = [...?widget.initial?.apps];
  Map<String, InstalledApp> _appInfo = const {};
  String? _nameError;

  /// Položky, ktoré boli v zozname pri otvorení – počas časového blokovania sa nedajú odobrať.
  late final Set<String> _lockedItems = {
    if (widget.locked) ...?widget.initial?.sites,
    if (widget.locked) ...?widget.initial?.apps,
  };

  @override
  void initState() {
    super.initState();
    widget.installedApps.then((apps) {
      if (mounted) setState(() => _appInfo = {for (final a in apps) a.package: a});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isNew => widget.initial == null;

  void _applyTemplate(String name, String emoji, List<String> domains) {
    final services = knownServices.where((s) => domains.contains(s.domain));
    setState(() {
      if (_name.text.trim().isEmpty) _name.text = name;
      _emoji = emoji;
      _sites = {..._sites, ...domains}.toList();
      _apps = {
        ..._apps,
        for (final s in services)
          for (final p in s.packages)
            if (_appInfo.containsKey(p)) p,
      }.toList();
    });
  }

  Future<void> _addItems() async {
    final s = S.of(context);
    final result = await showModalBottomSheet<AddResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => AddSheet(
        existingSites: _sites,
        existingApps: _apps,
        installedApps: widget.installedApps,
        title: s.addItems,
      ),
    );
    if (result == null) return;
    setState(() {
      _sites = {..._sites, ...result.sites}.toList();
      _apps = {..._apps, ...result.apps}.toList();
    });
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = S.of(context).nameRequired);
      return;
    }
    Navigator.pop(
      context,
      BlockList(
        id: widget.initial?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: name,
        emoji: _emoji,
        sites: _sites,
        apps: _apps,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? s.newList : s.editList),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(onPressed: _save, child: Text(s.save)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItems,
        icon: const Icon(Icons.add_rounded),
        label: Text(s.addItems),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom + 100),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
            decoration: InputDecoration(
              labelText: s.listName,
              hintText: s.listNameHint,
              errorText: _nameError,
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(s.listIcon, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final e in _emojis)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  selected: _emoji == e,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          if (_isNew && _sites.isEmpty && _apps.isEmpty) ...[
            const SizedBox(height: 20),
            Text(s.templates,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Text('💬'),
                  label: Text(s.tplSocial),
                  onPressed: () => _applyTemplate(s.tplSocial, '💬', const [
                    'instagram.com', 'facebook.com', 'tiktok.com', 'x.com', 'snapchat.com', 'reddit.com',
                  ]),
                ),
                ActionChip(
                  avatar: const Text('🎬'),
                  label: Text(s.tplVideo),
                  onPressed: () => _applyTemplate(s.tplVideo, '🎬', const [
                    'youtube.com', 'netflix.com', 'twitch.tv',
                  ]),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text('${s.listItemsTitle} · ${_sites.length + _apps.length}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (widget.locked) ...[
            Notice(text: s.listLockedEdit, icon: Icons.lock_clock_rounded),
            const SizedBox(height: 8),
          ],
          if (_sites.isEmpty && _apps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(s.listEmptyItems,
                  textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          for (final pkg in _apps)
            _ItemRow(
              leading: AppIcon(app: _appInfo[pkg], size: 40),
              title: _appInfo[pkg]?.label ?? pkg,
              subtitle: s.app,
              onRemove: _lockedItems.contains(pkg) ? null : () => setState(() => _apps.remove(pkg)),
            ),
          for (final site in _sites)
            _ItemRow(
              leading: SiteAvatar(entry: site, size: 40),
              title: serviceForDomain(site)?.name ?? site,
              subtitle: site,
              onRemove: _lockedItems.contains(site) ? null : () => setState(() => _sites.remove(site)),
            ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(12), child: leading),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          if (onRemove == null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.lock_rounded, size: 20, color: scheme.onSurfaceVariant),
            )
          else
            IconButton(
              tooltip: s.remove,
              icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
