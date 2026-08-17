import 'package:flutter/material.dart';

import '../../core/localization/app_locale_controller.dart';
import '../../core/localization/zenqivo_strings.dart';
import '../../core/models/profile.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/services/player_preferences_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.identity,
    required this.profile,
    required this.onSwitchProfile,
  });

  final DeviceIdentity identity;
  final ZenqivoProfile profile;
  final VoidCallback onSwitchProfile;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _service = PlayerPreferencesService();
  final _locale = AppLocaleController.instance;
  PlayerPreferences? _settings;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final value = await _service.load();
    if (mounted) setState(() => _settings = value);
  }

  Future<void> _configurePin() async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(ZText.t('الرقابة الأبوية', 'Parental Control')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                ZText.t(
                  'أنشئ رمز PIN من 4 إلى 6 أرقام لقفل المحتوى المصنف للكبار.',
                  'Create a 4-6 digit PIN to lock adult-rated content.',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(labelText: 'PIN'),
              ),
              TextField(
                controller: confirm,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: ZText.t('تأكيد PIN', 'Confirm PIN'),
                ),
              ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(ZText.t('إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () async {
                final valid = RegExp(r'^\d{4,6}$').hasMatch(pin.text);
                if (!valid || pin.text != confirm.text) {
                  setDialog(
                    () => error = ZText.t(
                      'اكتب PIN مطابقًا من 4 إلى 6 أرقام.',
                      'Enter matching 4-6 digit PINs.',
                    ),
                  );
                  return;
                }
                await _service.setPin(pin.text);
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(ZText.t('حفظ', 'Save')),
            ),
          ],
        ),
      ),
    );
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            ZText.settings,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),

          _Panel(
            child: ListTile(
              leading: const Icon(
                Icons.account_circle_rounded,
                color: ZenqivoColors.gold,
              ),
              title: Text(ZText.t('الملف الشخصي الحالي', 'Current Profile')),
              subtitle: Text(widget.profile.name),
              trailing: FilledButton.tonal(
                onPressed: widget.onSwitchProfile,
                child: Text(ZText.t('تبديل', 'Switch')),
              ),
            ),
          ),

          _Panel(
            child: ListTile(
              leading: const Icon(Icons.language_rounded, color: ZenqivoColors.gold),
              title: Text(ZText.language),
              subtitle: Text(
                _locale.isArabic ? ZText.arabic : ZText.english,
              ),
              trailing: DropdownButton<String>(
                value: _locale.locale.languageCode,
                items: const [
                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  await _locale.setLanguage(value);
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),

          _Panel(
            child: SwitchListTile(
              secondary: const Icon(
                Icons.play_circle_rounded,
                color: ZenqivoColors.gold,
              ),
              title: Text(ZText.t('تشغيل تلقائي', 'Autoplay')),
              subtitle: Text(
                ZText.t(
                  'بدء تشغيل المحتوى فور فتح المشغل',
                  'Start playback when the player opens',
                ),
              ),
              value: settings?.autoplay ?? true,
              onChanged: settings == null
                  ? null
                  : (v) async {
                      await _service.setAutoplay(v);
                      await _reload();
                    },
            ),
          ),

          _Panel(
            child: ListTile(
              leading: const Icon(
                Icons.high_quality_rounded,
                color: ZenqivoColors.gold,
              ),
              title: Text(
                ZText.t('جودة التشغيل المفضلة', 'Preferred Playback Quality'),
              ),
              subtitle: Text(settings?.quality ?? 'Auto'),
              trailing: DropdownButton<String>(
                value: settings?.quality ?? 'Auto',
                items: const [
                  DropdownMenuItem(value: 'Auto', child: Text('Auto')),
                  DropdownMenuItem(value: '4K', child: Text('4K')),
                  DropdownMenuItem(value: '1080p', child: Text('1080p')),
                  DropdownMenuItem(value: '720p', child: Text('720p')),
                ],
                onChanged: settings == null
                    ? null
                    : (v) async {
                        if (v == null) return;
                        await _service.setQuality(v);
                        await _reload();
                      },
              ),
            ),
          ),

          _Panel(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.lock_rounded,
                    color: ZenqivoColors.gold,
                  ),
                  title: Text(
                    ZText.t('الرقابة الأبوية', 'Parental Control'),
                  ),
                  subtitle: Text(
                    ZText.t(
                      'قفل المحتوى المصنف للكبار بواسطة PIN',
                      'Lock adult-rated content using a PIN',
                    ),
                  ),
                  value: settings?.parentalEnabled ?? false,
                  onChanged: settings == null
                      ? null
                      : (v) async {
                          if (v) {
                            await _configurePin();
                          } else {
                            await _service.disableParental();
                            await _reload();
                          }
                        },
                ),
                if (settings?.parentalEnabled == true)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _configurePin,
                      icon: const Icon(Icons.password_rounded),
                      label: Text(ZText.t('تغيير PIN', 'Change PIN')),
                    ),
                  ),
              ],
            ),
          ),


          _Panel(
            child: ListTile(
              leading: const Icon(
                Icons.info_outline_rounded,
                color: ZenqivoColors.gold,
              ),
              title: Text(ZText.t('حول التطبيق', 'About')),
              subtitle: const Text('ZENQIVO Player 0.10.0'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
            ),
          ),

          _Panel(
            child: ListTile(
              leading: const Icon(
                Icons.devices_rounded,
                color: ZenqivoColors.gold,
              ),
              title: Text(ZText.t('بيانات الجهاز', 'Device Details')),
              subtitle: Text(
                'ID: ${widget.identity.deviceId}\nKEY: ${widget.identity.deviceKey}',
              ),
              isThreeLine: true,
            ),
          ),

          const SizedBox(height: 10),
          Text(
            ZText.t(
              'ZENQIVO Player لا يوفّر محتوى أو قنوات. التشغيل يعتمد على المصادر التي يملك المستخدم صلاحية استخدامها.',
              'ZENQIVO Player does not provide channels or content. Playback depends on sources the user is authorized to use.',
            ),
            style: const TextStyle(
              fontSize: 12,
              color: ZenqivoColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
