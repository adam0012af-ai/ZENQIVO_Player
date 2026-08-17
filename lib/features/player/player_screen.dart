import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/config/zenqivo_config.dart';
import '../../core/localization/zenqivo_strings.dart';
import '../../core/models/media_item.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.item,
    this.queue = const [],
    this.initialIndex = 0,
  });

  final MediaItem item;
  final List<MediaItem> queue;
  final int initialIndex;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final _prefs = PlayerPreferencesService();
  final _focus = FocusNode();

  late final Player _player = Player();
  late final VideoController _controller = VideoController(_player);

  StreamSubscription<String>? _errorSub;
  late MediaItem _item;
  late int _queueIndex;

  bool _showControls = true;
  String? _error;
  BoxFit _fit = BoxFit.contain;

  @override
  void initState() {
    super.initState();
    _item = widget.item;
    _queueIndex = widget.queue.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.queue.length - 1);

    _errorSub = _player.stream.error.listen((message) {
      if (mounted && message.trim().isNotEmpty) {
        setState(() => _error = ZText.t('تعذر تشغيل المصدر الحالي.', 'Unable to play the current source.'));
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final allowed = await _authorizeCurrent();
      if (!mounted) return;
      if (!allowed) {
        Navigator.maybePop(context);
        return;
      }
      await _openCurrent();
      if (mounted) _focus.requestFocus();
    });
  }


  Future<bool> _authorizeCurrent() async {
    final settings = await _prefs.load();
    if (!settings.parentalEnabled || !_item.isAdult) return true;
    if (!mounted) return false;

    final controller = TextEditingController();
    String? error;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ZText.t('رمز الرقابة الأبوية', 'Parental PIN')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ZText.t('أدخل رمز الرقابة الأبوية لتشغيل هذا المحتوى.', 'Enter the parental PIN to play this content.')),
              const SizedBox(height: 10),
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
                final ok = await _prefs.verifyPin(controller.text);
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

  Future<void> _openCurrent() async {
    setState(() => _error = null);

    await _prefs.addRecent(_item.id);
    final settings = await _prefs.load();

    try {
      await _player.open(
        Media(
          _item.streamUrl,
          httpHeaders: const {
            'Accept': '*/*',
            'User-Agent': ZenqivoConfig.userAgent,
          },
        ),
        play: settings.autoplay,
      );

      if (_item.kind != MediaKind.live) {
        final saved = await _prefs.loadProgress(_item.id);
        if (saved != null && saved > Duration.zero) {
          await _player.seek(saved);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = ZText.t('تعذر تشغيل المصدر الحالي.', 'Unable to play the current source.'));
    }
  }

  Future<void> _saveProgress() async {
    if (_item.kind == MediaKind.live) return;
    final position = _player.state.position;
    if (position > Duration.zero) {
      await _prefs.saveProgress(_item.id, position);
    }
  }

  Future<void> _switchQueue(int delta) async {
    if (widget.queue.length < 2) return;
    await _saveProgress();

    var next = _queueIndex + delta;
    if (next < 0) next = widget.queue.length - 1;
    if (next >= widget.queue.length) next = 0;

    setState(() {
      _queueIndex = next;
      _item = widget.queue[next];
      _showControls = true;
    });
    await _openCurrent();
  }

  Future<void> _seek(int seconds) async {
    if (_item.kind == MediaKind.live) return;
    final duration = _player.state.duration;
    final current = _player.state.position;
    var target = current + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _player.seek(target);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.space) {
      _player.playOrPause();
      setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      _seek(-10);
      setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      _seek(10);
      setState(() => _showControls = true);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowUp &&
        _item.kind == MediaKind.live &&
        widget.queue.isNotEmpty) {
      _switchQueue(-1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowDown &&
        _item.kind == MediaKind.live &&
        widget.queue.isNotEmpty) {
      _switchQueue(1);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _saveProgress();
    _errorSub?.cancel();
    _focus.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _showAudioTracks() async {
    final tracks = _player.state.tracks.audio;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZenqivoColors.surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              title: Text(
                ZText.t('المسار الصوتي', 'Audio Track'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: Text(ZText.t('تلقائي', 'Auto')),
              onTap: () async {
                await _player.setAudioTrack(AudioTrack.auto());
                if (context.mounted) Navigator.pop(context);
              },
            ),
            for (final track in tracks)
              ListTile(
                leading: Icon(
                  _player.state.track.audio.id == track.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: ZenqivoColors.gold,
                ),
                title: Text(_trackLabel(track.title, track.language, track.id)),
                subtitle: track.codec == null ? null : Text(track.codec!),
                onTap: () async {
                  await _player.setAudioTrack(track);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    _focus.requestFocus();
  }

  Future<void> _showSubtitleTracks() async {
    final tracks = _player.state.tracks.subtitle;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZenqivoColors.surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              title: Text(
                ZText.t('الترجمة', 'Subtitles'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.subtitles_off_rounded),
              title: Text(ZText.t('إيقاف الترجمة', 'Subtitles Off')),
              onTap: () async {
                await _player.setSubtitleTrack(SubtitleTrack.no());
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: Text(ZText.t('تلقائي', 'Auto')),
              onTap: () async {
                await _player.setSubtitleTrack(SubtitleTrack.auto());
                if (context.mounted) Navigator.pop(context);
              },
            ),
            for (final track in tracks)
              ListTile(
                leading: Icon(
                  _player.state.track.subtitle.id == track.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: ZenqivoColors.gold,
                ),
                title: Text(_trackLabel(track.title, track.language, track.id)),
                subtitle: track.codec == null ? null : Text(track.codec!),
                onTap: () async {
                  await _player.setSubtitleTrack(track);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: Text(ZText.t('تحميل ترجمة خارجية من رابط', 'Load External Subtitle from URL')),
              onTap: () {
                Navigator.pop(context);
                _loadExternalSubtitle();
              },
            ),
          ],
        ),
      ),
    );
    _focus.requestFocus();
  }

  Future<void> _loadExternalSubtitle() async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ZText.t('ترجمة خارجية', 'External Subtitle')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://example.com/subtitle.srt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(ZText.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(ZText.t('تحميل', 'Load')),
          ),
        ],
      ),
    );

    if (url != null && url.isNotEmpty) {
      try {
        await _player.setSubtitleTrack(
          SubtitleTrack.uri(url, title: 'External'),
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(ZText.t('تعذر تحميل ملف الترجمة.', 'Unable to load the subtitle file.'))),
          );
        }
      }
    }
    _focus.requestFocus();
  }

  Future<void> _showSpeed() async {
    final speeds = <double>[0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: ZenqivoColors.surface,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(12),
          children: [
            ListTile(
              title: Text(
                ZText.t('سرعة التشغيل', 'Playback Speed'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final speed in speeds)
              ListTile(
                leading: Icon(
                  (_player.state.rate - speed).abs() < 0.01
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: ZenqivoColors.gold,
                ),
                title: Text('${speed}x'),
                onTap: () async {
                  await _player.setRate(speed);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
    _focus.requestFocus();
  }

  void _cycleFit() {
    setState(() {
      _fit = switch (_fit) {
        BoxFit.contain => BoxFit.cover,
        BoxFit.cover => BoxFit.fill,
        _ => BoxFit.contain,
      };
    });
  }

  String _fitLabel() => switch (_fit) {
        BoxFit.contain => ZText.t('ملائم', 'Fit'),
        BoxFit.cover => ZText.t('ملء الشاشة', 'Fill Screen'),
        BoxFit.fill => ZText.t('تمديد', 'Stretch'),
        _ => ZText.t('ملائم', 'Fit'),
      };

  String _trackLabel(String? title, String? language, String id) {
    final values = <String>[
      if (title != null && title.trim().isNotEmpty) title.trim(),
      if (language != null && language.trim().isNotEmpty) language.trim(),
    ];
    return values.isEmpty ? 'Track $id' : values.join(' · ');
  }

  String _duration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '${value.inMinutes}:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showControls = !_showControls),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Video(
                  controller: _controller,
                  fit: _fit,
                  controls: NoVideoControls,
                  subtitleViewConfiguration: const SubtitleViewConfiguration(
                    style: TextStyle(
                      height: 1.35,
                      fontSize: 24,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      backgroundColor: Color(0xAA000000),
                    ),
                    textAlign: TextAlign.center,
                    padding: EdgeInsets.fromLTRB(28, 28, 28, 50),
                  ),
                ),
              ),
              if (_error != null)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xCC000000),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              if (_showControls)
                _buildControls(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xD9000000),
            Color(0x15000000),
            Color(0xE6000000),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _TvButton(
                    icon: Icons.arrow_back_rounded,
                    label: ZText.t('رجوع', 'Back'),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (_item.group != null)
                          Text(
                            _item.group!,
                            style: const TextStyle(color: Colors.white60),
                          ),
                      ],
                    ),
                  ),
                  if (_item.kind == MediaKind.live)
                    const Chip(
                      avatar: Icon(Icons.circle, size: 10, color: Colors.redAccent),
                      label: Text('LIVE'),
                    ),
                ],
              ),
              const Spacer(),
              if (_item.kind == MediaKind.live && widget.queue.length > 1)
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    ZText.t('↑ ↓ لتغيير القناة سريعًا', '↑ ↓ to change channels quickly'),
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              if (_item.kind != MediaKind.live)
                StreamBuilder<Duration>(
                  stream: _player.stream.position,
                  initialData: _player.state.position,
                  builder: (context, positionSnapshot) {
                    return StreamBuilder<Duration>(
                      stream: _player.stream.duration,
                      initialData: _player.state.duration,
                      builder: (context, durationSnapshot) {
                        final position = positionSnapshot.data ?? Duration.zero;
                        final duration = durationSnapshot.data ?? Duration.zero;
                        final max = duration.inMilliseconds <= 0
                            ? 1.0
                            : duration.inMilliseconds.toDouble();
                        final value = position.inMilliseconds
                            .clamp(0, max.toInt())
                            .toDouble();

                        return Row(
                          children: [
                            SizedBox(
                              width: 65,
                              child: Text(_duration(position)),
                            ),
                            Expanded(
                              child: Slider(
                                value: value,
                                max: max,
                                activeColor: ZenqivoColors.gold,
                                onChanged: (v) =>
                                    _player.seek(Duration(milliseconds: v.toInt())),
                              ),
                            ),
                            SizedBox(
                              width: 65,
                              child: Text(
                                _duration(duration),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_item.kind != MediaKind.live)
                    _TvButton(
                      icon: Icons.replay_10_rounded,
                      label: '-10',
                      onPressed: () => _seek(-10),
                    ),
                  const SizedBox(width: 8),
                  StreamBuilder<bool>(
                    stream: _player.stream.playing,
                    initialData: _player.state.playing,
                    builder: (context, snapshot) => _TvButton(
                      icon: snapshot.data == true
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      label: snapshot.data == true ? ZText.t('إيقاف', 'Pause') : ZText.t('تشغيل', 'Play'),
                      prominent: true,
                      onPressed: _player.playOrPause,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_item.kind != MediaKind.live)
                    _TvButton(
                      icon: Icons.forward_10_rounded,
                      label: '+10',
                      onPressed: () => _seek(10),
                    ),
                  const SizedBox(width: 18),
                  _TvButton(
                    icon: Icons.audiotrack_rounded,
                    label: ZText.t('الصوت', 'Audio'),
                    onPressed: _showAudioTracks,
                  ),
                  const SizedBox(width: 8),
                  _TvButton(
                    icon: Icons.subtitles_rounded,
                    label: ZText.t('الترجمة', 'Subtitles'),
                    onPressed: _showSubtitleTracks,
                  ),
                  const SizedBox(width: 8),
                  if (_item.kind != MediaKind.live)
                    _TvButton(
                      icon: Icons.speed_rounded,
                      label: '${_player.state.rate}x',
                      onPressed: _showSpeed,
                    ),
                  const SizedBox(width: 8),
                  _TvButton(
                    icon: Icons.aspect_ratio_rounded,
                    label: _fitLabel(),
                    onPressed: _cycleFit,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StreamBuilder<bool>(
                stream: _player.stream.buffering,
                initialData: _player.state.buffering,
                builder: (context, snapshot) {
                  if (snapshot.data != true) return const SizedBox(height: 3);
                  return const LinearProgressIndicator(
                    minHeight: 3,
                    color: ZenqivoColors.gold,
                    backgroundColor: Colors.white12,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TvButton extends StatefulWidget {
  const _TvButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool prominent;

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => _focused = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _focused ? ZenqivoColors.gold : Colors.transparent,
            width: 2,
          ),
          boxShadow: _focused
              ? const [
                  BoxShadow(
                    color: Color(0x55D4AF37),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: FilledButton.tonalIcon(
          autofocus: widget.prominent,
          onPressed: widget.onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: widget.prominent
                ? ZenqivoColors.gold
                : const Color(0xDD1B1B1B),
            foregroundColor: widget.prominent ? Colors.black : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          ),
          icon: Icon(widget.icon, size: widget.prominent ? 28 : 21),
          label: Text(widget.label),
        ),
      ),
    );
  }
}
