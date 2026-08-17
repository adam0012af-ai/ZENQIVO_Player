import 'package:flutter/material.dart';

import '../../core/localization/zenqivo_strings.dart';
import '../../core/models/playlist.dart';
import '../../core/models/profile.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../home/home_shell.dart';

class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({
    super.key,
    required this.identity,
    required this.playlists,
    required this.syncedAt,
  });

  final DeviceIdentity identity;
  final List<ZenqivoPlaylist> playlists;
  final DateTime syncedAt;

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  final _service = ProfileService();
  late Future<List<ZenqivoProfile>> _future = _service.list();

  static const _avatars = [
    Icons.person_rounded,
    Icons.face_rounded,
    Icons.sentiment_satisfied_alt_rounded,
    Icons.smart_toy_rounded,
    Icons.sports_esports_rounded,
    Icons.movie_filter_rounded,
  ];

  Future<void> _select(ZenqivoProfile profile) async {
    await _service.setActive(profile.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomeShell(
          identity: widget.identity,
          playlists: widget.playlists,
          syncedAt: widget.syncedAt,
          profile: profile,
        ),
      ),
    );
  }


  Future<void> _editProfile(ZenqivoProfile profile) async {
    final name = TextEditingController(text: profile.name);
    var avatar = profile.avatarIndex % _avatars.length;
    String? error;

    final updated = await showDialog<ZenqivoProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ZText.t('تعديل الملف الشخصي', 'Edit Profile')),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: ZText.t('اسم الملف الشخصي', 'Profile name'),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < _avatars.length; i++)
                      InkWell(
                        onTap: () => setDialogState(() => avatar = i),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: avatar == i
                                ? const Color(0xFF3A3113)
                                : ZenqivoColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: avatar == i
                                  ? ZenqivoColors.gold
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _avatars[i],
                            color: avatar == i
                                ? ZenqivoColors.goldSoft
                                : ZenqivoColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ZText.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final value = name.text.trim();
                if (value.length < 2) {
                  setDialogState(() => error = ZText.t(
                        'اكتب اسمًا صحيحًا.',
                        'Enter a valid name.',
                      ));
                  return;
                }
                final result = await _service.update(
                  profile.id,
                  name: value,
                  avatarIndex: avatar,
                );
                if (context.mounted) Navigator.pop(context, result);
              },
              child: Text(ZText.t('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() => _future = _service.list());
    }
  }

  Future<void> _deleteProfile(ZenqivoProfile profile) async {
    final profiles = await _service.list();
    if (profiles.length <= 1) return;
    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ZText.t('حذف الملف الشخصي', 'Delete Profile')),
        content: Text(
          ZText.t(
            'سيتم حذف ${profile.name} من هذا الجهاز.',
            'Remove ${profile.name} from this device?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ZText.t('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ZText.t('حذف', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _service.remove(profile.id);
      if (mounted) setState(() => _future = _service.list());
    }
  }

  Future<void> _addProfile() async {
    final name = TextEditingController();
    var avatar = 0;
    String? error;

    final created = await showDialog<ZenqivoProfile>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(ZText.addProfile),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: ZText.t('اسم الملف الشخصي', 'Profile name'),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < _avatars.length; i++)
                      InkWell(
                        onTap: () => setDialogState(() => avatar = i),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: avatar == i
                                ? const Color(0xFF3A3113)
                                : ZenqivoColors.surfaceRaised,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: avatar == i
                                  ? ZenqivoColors.gold
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _avatars[i],
                            color: avatar == i
                                ? ZenqivoColors.goldSoft
                                : ZenqivoColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ZText.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final value = name.text.trim();
                if (value.length < 2) {
                  setDialogState(() => error =
                      ZText.t('اكتب اسمًا صحيحًا.', 'Enter a valid name.'));
                  return;
                }
                try {
                  final profile = await _service.add(value, avatar);
                  if (context.mounted) Navigator.pop(context, profile);
                } on StateError {
                  setDialogState(() => error = ZText.t(
                        'الحد الأقصى 6 ملفات شخصية.',
                        'Maximum 6 profiles.',
                      ));
                }
              },
              child: Text(ZText.t('إضافة', 'Add')),
            ),
          ],
        ),
      ),
    );

    if (created != null) {
      setState(() => _future = _service.list());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: FutureBuilder<List<ZenqivoProfile>>(
                future: _future,
                builder: (context, snapshot) {
                  final profiles = snapshot.data ?? const <ZenqivoProfile>[];
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ZENQIVO',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        ZText.chooseProfile,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 34),
                      if (snapshot.connectionState != ConnectionState.done)
                        const CircularProgressIndicator(color: ZenqivoColors.gold)
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 22,
                          runSpacing: 22,
                          children: [
                            for (final profile in profiles)
                              _ProfileCard(
                                profile: profile,
                                icon: _avatars[
                                    profile.avatarIndex % _avatars.length],
                                onTap: () => _select(profile),
                                onEdit: () => _editProfile(profile),
                                onDelete: () => _deleteProfile(profile),
                              ),
                            if (profiles.length < 6)
                              _AddCard(onTap: _addProfile),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({
    required this.profile,
    required this.icon,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ZenqivoProfile profile;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool focused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowFocusHighlight: (value) => setState(() => focused = value),
      child: AnimatedScale(
        scale: focused ? 1.06 : 1,
        duration: const Duration(milliseconds: 120),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(28),
          child: SizedBox(
            width: 150,
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF302812), Color(0xFF111111)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: focused
                          ? ZenqivoColors.gold
                          : const Color(0xFF403719),
                      width: focused ? 3 : 1,
                    ),
                    boxShadow: focused
                        ? const [
                            BoxShadow(
                              color: Color(0x55D4AF37),
                              blurRadius: 20,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 66,
                    color: ZenqivoColors.goldSoft,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        widget.profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    PopupMenuButton<String>(
                      iconSize: 18,
                      onSelected: (value) {
                        if (value == 'edit') widget.onEdit();
                        if (value == 'delete') widget.onDelete();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(ZText.t('تعديل', 'Edit')),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(ZText.t('حذف', 'Delete')),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddCard extends StatelessWidget {
  const _AddCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        width: 150,
        child: Column(
          children: [
            Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: ZenqivoColors.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF373737)),
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 54,
                color: ZenqivoColors.gold,
              ),
            ),
            const SizedBox(height: 12),
            Text(ZText.addProfile),
          ],
        ),
      ),
    );
  }
}
