import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';
import 'package:flutter/services.dart';

import '../../core/models/epg_program.dart';
import '../../core/models/media_item.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../player/player_screen.dart';

class LiveTvScreen extends StatefulWidget {
  const LiveTvScreen({
    super.key,
    required this.items,
    required this.epg,
  });

  final List<MediaItem> items;
  final Map<String, List<EpgProgram>> epg;

  @override
  State<LiveTvScreen> createState() => _LiveTvScreenState();
}

class _LiveTvScreenState extends State<LiveTvScreen> {
  final _prefs = PlayerPreferencesService();
  final _focus = FocusNode();
  Set<String> _favorites = {};
  String? _group;
  int _selected = 0;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final values = await _prefs.favorites();
    if (mounted) setState(() => _favorites = values);
  }

  List<MediaItem> get _channels {
    Iterable<MediaItem> values = widget.items.where((e) => e.kind == MediaKind.live);
    if (_group != null) values = values.where((e) => e.group == _group);
    if (_query.trim().isNotEmpty) {
      final q = _query.trim().toLowerCase();
      values = values.where((e) => e.title.toLowerCase().contains(q));
    }
    return values.toList();
  }

  List<String> get _groups {
    final groups = widget.items
        .where((e) => e.kind == MediaKind.live)
        .map((e) => e.group)
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return groups;
  }

  MediaItem? get _current {
    final channels = _channels;
    if (channels.isEmpty) return null;
    final safe = _selected.clamp(0, channels.length - 1);
    return channels[safe];
  }

  List<EpgProgram> _programs(MediaItem item) {
    final id = item.tvgId;
    if (id == null) return const [];
    final now = DateTime.now().subtract(const Duration(hours: 1));
    final end = DateTime.now().add(const Duration(hours: 8));
    return (widget.epg[id] ?? const [])
        .where((e) => e.stop.isAfter(now) && e.start.isBefore(end))
        .take(12)
        .toList();
  }

  Future<void> _open(MediaItem item) async {
    final settings = await _prefs.load();
    if (settings.parentalEnabled && item.isAdult && mounted) {
      final ok = await _askPin(context, _prefs);
      if (!ok || !mounted) return;
    }
    if (!mounted) return;
    final queue = _channels;
    final queueIndex = queue.indexWhere((e) => e.id == item.id);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          item: item,
          queue: queue,
          initialIndex: queueIndex < 0 ? 0 : queueIndex,
        ),
      ),
    );
    _focus.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final channels = _channels;
    if (channels.isEmpty) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _selected = (_selected + 1).clamp(0, channels.length - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _selected = (_selected - 1).clamp(0, channels.length - 1));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.select) {
      final item = _current;
      if (item != null) _open(item);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final channels = _channels;
    if (_selected >= channels.length && channels.isNotEmpty) {
      _selected = channels.length - 1;
    }

    final selected = _current;
    return SafeArea(
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.live_tv_rounded, color: ZenqivoColors.gold),
              const SizedBox(width: 10),
              Text(
                ZText.t('البث المباشر', 'Live TV'),
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              SizedBox(
                width: 280,
                child: TextField(
                  onChanged: (v) => setState(() {
                    _query = v;
                    _selected = 0;
                  }),
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: ZText.t('بحث عن قناة', 'Search channels'),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: Row(children: [
                SizedBox(
                  width: 230,
                  child: _CategoryPanel(
                    groups: _groups,
                    selected: _group,
                    onSelected: (value) => setState(() {
                      _group = value;
                      _selected = 0;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 360,
                  child: _ChannelPanel(
                    channels: channels,
                    selectedIndex: _selected,
                    favorites: _favorites,
                    onSelect: (index) => setState(() => _selected = index),
                    onOpen: _open,
                    onFavorite: (item) async {
                      await _prefs.toggleFavorite(item.id);
                      await _loadFavorites();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: selected == null
                      ? const Center(
                          child: Text(
                            ZText.t('لا توجد قنوات.', 'No channels available.'),
                            style: TextStyle(color: ZenqivoColors.muted),
                          ),
                        )
                      : _GuidePanel(
                          item: selected,
                          programs: _programs(selected),
                          onPlay: () => _open(selected),
                        ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CategoryPanel extends StatelessWidget {
  const _CategoryPanel({
    required this.groups,
    required this.selected,
    required this.onSelected,
  });

  final List<String> groups;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          ListTile(
            selected: selected == null,
            selectedTileColor: const Color(0xFF302812),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            leading: const Icon(Icons.apps_rounded),
            title: Text(ZText.t('كل القنوات', 'All Channels')),
            onTap: () => onSelected(null),
          ),
          for (final group in groups)
            ListTile(
              selected: selected == group,
              selectedTileColor: const Color(0xFF302812),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              title: Text(group, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => onSelected(group),
            ),
        ],
      ),
    );
  }
}

class _ChannelPanel extends StatelessWidget {
  const _ChannelPanel({
    required this.channels,
    required this.selectedIndex,
    required this.favorites,
    required this.onSelect,
    required this.onOpen,
    required this.onFavorite,
  });

  final List<MediaItem> channels;
  final int selectedIndex;
  final Set<String> favorites;
  final ValueChanged<int> onSelect;
  final ValueChanged<MediaItem> onOpen;
  final ValueChanged<MediaItem> onFavorite;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: channels.isEmpty
          ? Center(child: Text(ZText.t('لا توجد قنوات', 'No channels available')))
          : ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final item = channels[index];
                return ListTile(
                  selected: index == selectedIndex,
                  selectedTileColor: const Color(0xFF302812),
                  onTap: () => onSelect(index),
                  onLongPress: () => onOpen(item),
                  leading: SizedBox(
                    width: 42,
                    height: 42,
                    child: item.logoUrl == null || item.logoUrl!.isEmpty
                        ? const Icon(Icons.live_tv_rounded, color: ZenqivoColors.gold)
                        : Image.network(
                            item.logoUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.live_tv_rounded,
                              color: ZenqivoColors.gold,
                            ),
                          ),
                  ),
                  title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    item.group ?? ZText.live,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    onPressed: () => onFavorite(item),
                    icon: Icon(
                      favorites.contains(item.id)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: favorites.contains(item.id) ? ZenqivoColors.gold : null,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.item,
    required this.programs,
    required this.onPlay,
  });

  final MediaItem item;
  final List<EpgProgram> programs;
  final VoidCallback onPlay;

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2B2411), Color(0xFF111111)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  item.title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  item.group ?? ZText.t('بث مباشر', 'Live TV'),
                  style: const TextStyle(color: ZenqivoColors.muted),
                ),
              ]),
            ),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(ZText.t('تشغيل', 'Play')),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 8),
          child: Text(
            ZText.t('دليل البرامج', 'Program Guide'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: programs.isEmpty
              ? const Center(
                  child: Text(
                    ZText.t('لا تتوفر بيانات EPG لهذه القناة.', 'No EPG data is available for this channel.'),
                    style: TextStyle(color: ZenqivoColors.muted),
                  ),
                )
              : ListView.builder(
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    final p = programs[index];
                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.isNow ? const Color(0xFF28220F) : ZenqivoColors.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: p.isNow
                            ? Border.all(color: const Color(0xFF625019))
                            : null,
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(
                            '${_time(p.start)} - ${_time(p.stop)}',
                            style: TextStyle(
                              color: p.isNow ? ZenqivoColors.goldSoft : ZenqivoColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          if (p.isNow) ...[
                            const SizedBox(width: 8),
                            Text(
                              ZText.t('الآن', 'Now'),
                              style: TextStyle(
                                color: ZenqivoColors.gold,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 5),
                        Text(
                          p.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (p.isNow) ...[
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: p.progress,
                            minHeight: 3,
                            backgroundColor: Colors.white12,
                            color: ZenqivoColors.gold,
                          ),
                        ],
                      ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}


Future<bool> _askPin(BuildContext context, PlayerPreferencesService prefs) async {
  final controller = TextEditingController();
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(ZText.t('محتوى مقفول', 'Locked Content')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ZText.t('أدخل رمز الرقابة الأبوية للمتابعة.', 'Enter the parental PIN to continue.')),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
            ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.redAccent)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ZText.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final ok = await prefs.verifyPin(controller.text);
              if (ok && context.mounted) {
                Navigator.pop(context, true);
              } else {
                setDialogState(() => error = ZText.t('الرمز غير صحيح', 'Incorrect PIN'));
              }
            },
            child: Text(ZText.t('فتح', 'Unlock')),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
