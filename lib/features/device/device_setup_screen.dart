import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/zenqivo_api.dart';
import '../../core/localization/zenqivo_strings.dart';
import '../../core/services/device_identity_service.dart';
import '../../core/theme/zenqivo_theme.dart';
import '../profile/profile_selection_screen.dart';

class DeviceSetupScreen extends StatefulWidget {
  const DeviceSetupScreen({super.key});

  @override
  State<DeviceSetupScreen> createState() => _DeviceSetupScreenState();
}

class _DeviceSetupScreenState extends State<DeviceSetupScreen> {
  final _identityService = const DeviceIdentityService();
  final _api = ZenqivoApi();
  late final Future<DeviceIdentity> _identity = _identityService.getOrCreate();

  bool _checking = false;
  String? _message;
  DeviceStatus? _status;

  @override
  void initState() {
    super.initState();
    _register();
  }


  String _friendlyError(Object error) {
    if (error is ZenqivoApiException) {
      switch (error.code) {
        case 'device_not_active':
          return ZText.t(
            'انتهى التفعيل أو الجهاز غير مفعّل. فعّل الجهاز ثم أعد المحاولة.',
            'Activation has expired or the device is inactive. Activate it and try again.',
          );
        case 'device_not_found':
          return ZText.t(
            'الجهاز غير مسجل على الخادم.',
            'This device is not registered on the server.',
          );
        case 'invalid_device_key':
          return ZText.t(
            'تعذر التحقق من هوية الجهاز.',
            'Device identity verification failed.',
          );
        case 'invalid_server_response':
          return ZText.t(
            'استجابة الخادم غير صالحة.',
            'The server returned an invalid response.',
          );
      }
    }
    return ZText.t(
      'تعذر الاتصال بخادم ZENQIVO. تحقق من الإنترنت وحاول مرة أخرى.',
      'Unable to reach the ZENQIVO server. Check your connection and try again.',
    );
  }

  Future<void> _register() async {
    setState(() => _checking = true);
    try {
      final identity = await _identity;
      final status = await _api.register(identity);
      if (!mounted) return;
      setState(() {
        _status = status;
        _message = status.active
            ? ZText.t('الجهاز مفعّل وجاهز.', 'Device activated and ready.')
            : ZText.t(
                'الجهاز بانتظار التفعيل من لوحة ZENQIVO.',
                'This device is waiting for activation.',
              );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _checkAndContinue(DeviceIdentity identity) async {
    setState(() {
      _checking = true;
      _message = ZText.t(
        'جاري فحص حالة التفعيل...',
        'Checking activation status...',
      );
    });

    try {
      final status = await _api.status(identity);
      if (!mounted) return;

      if (!status.active) {
        setState(() {
          _status = status;
          _message = ZText.t(
            'لم يتم تفعيل الجهاز بعد.',
            'The device has not been activated yet.',
          );
        });
        return;
      }

      final sync = await _api.sync(identity);
      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileSelectionScreen(
            identity: identity,
            playlists: sync.playlists,
            syncedAt: sync.syncedAt,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _message = _friendlyError(error));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<DeviceIdentity>(
          future: _identity,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: ZenqivoColors.gold),
              );
            }

            final identity = snapshot.data!;
            final active = _status?.active == true;

            return Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.55, -0.4),
                      radius: 1.1,
                      colors: [
                        Color(0xFF312812),
                        Color(0xFF0E0E0E),
                        ZenqivoColors.background,
                      ],
                    ),
                  ),
                ),
                Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: wide
                          ? Row(
                              children: [
                                Expanded(child: _WelcomePanel(active: active)),
                                const SizedBox(width: 28),
                                Expanded(
                                  child: _ActivationCard(
                                    identity: identity,
                                    active: active,
                                    checking: _checking,
                                    message: _message,
                                    status: _status,
                                    onCheck: () =>
                                        _checkAndContinue(identity),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _WelcomePanel(active: active),
                                const SizedBox(height: 24),
                                _ActivationCard(
                                  identity: identity,
                                  active: active,
                                  checking: _checking,
                                  message: _message,
                                  status: _status,
                                  onCheck: () =>
                                      _checkAndContinue(identity),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: ZenqivoColors.gold, width: 2),
              gradient: const LinearGradient(
                colors: [Color(0xFF2C2410), Color(0xFF090909)],
              ),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Z▶',
              style: TextStyle(
                color: ZenqivoColors.goldSoft,
                fontSize: 29,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 26),
          const Text(
            'ZENQIVO',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              letterSpacing: 7,
            ),
          ),
          const Text(
            'PLAYER',
            style: TextStyle(
              color: ZenqivoColors.gold,
              letterSpacing: 7,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            ZText.t(
              'شاهد محتواك بطريقتك.',
              'Your media. Your way.',
            ),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            ZText.t(
              'فعّل هذا الجهاز، اربط مصادر الوسائط المصرح لك باستخدامها، ثم اختر ملفك الشخصي وابدأ.',
              'Activate this device, connect media sources you are authorized to use, choose a profile, and start watching.',
            ),
            style: const TextStyle(
              color: ZenqivoColors.muted,
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Feature(icon: Icons.live_tv_rounded, text: 'Live TV'),
              _Feature(icon: Icons.movie_rounded, text: 'Movies'),
              _Feature(icon: Icons.video_library_rounded, text: 'Series'),
              _Feature(icon: Icons.calendar_month_rounded, text: 'EPG'),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Icon(
                active
                    ? Icons.verified_rounded
                    : Icons.hourglass_top_rounded,
                color: active
                    ? const Color(0xFF7BDD9A)
                    : ZenqivoColors.gold,
              ),
              const SizedBox(width: 8),
              Text(
                active
                    ? ZText.t('جاهز للمتابعة', 'Ready to continue')
                    : ZText.t('بانتظار التفعيل', 'Waiting for activation'),
                style: TextStyle(
                  color: active
                      ? const Color(0xFF7BDD9A)
                      : ZenqivoColors.goldSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({
    required this.identity,
    required this.active,
    required this.checking,
    required this.message,
    required this.status,
    required this.onCheck,
  });

  final DeviceIdentity identity;
  final bool active;
  final bool checking;
  final String? message;
  final DeviceStatus? status;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    final until = status?.activatedUntil;

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xEE111111),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF413718)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 36,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ZText.t('تفعيل الجهاز', 'Device Activation'),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ZText.t(
              'استخدم البيانات التالية في لوحة إدارة ZENQIVO.',
              'Use the following details in the ZENQIVO management portal.',
            ),
            style: const TextStyle(
              color: ZenqivoColors.muted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          _IdentityTile(
            label: 'DEVICE ID',
            value: identity.deviceId,
          ),
          const SizedBox(height: 12),
          _IdentityTile(
            label: 'DEVICE KEY',
            value: identity.deviceKey,
          ),
          if (until != null) ...[
            const SizedBox(height: 12),
            Text(
              '${ZText.t('صالح حتى', 'Active until')}: '
              '${until.year}-${until.month.toString().padLeft(2, '0')}-${until.day.toString().padLeft(2, '0')}',
              style: const TextStyle(
                color: ZenqivoColors.goldSoft,
                fontSize: 12,
              ),
            ),
          ],
          if (message != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF102116)
                    : const Color(0xFF211D10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active
                      ? const Color(0xFF89E6A3)
                      : ZenqivoColors.goldSoft,
                ),
              ),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: checking ? null : onCheck,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              backgroundColor: ZenqivoColors.gold,
              foregroundColor: Colors.black,
            ),
            icon: checking
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : Icon(
                    active
                        ? Icons.arrow_forward_rounded
                        : Icons.verified_rounded,
                  ),
            label: Text(
              checking
                  ? ZText.t('جاري الفحص...', 'Checking...')
                  : active
                      ? ZText.t('المتابعة', 'Continue')
                      : ZText.t(
                          'فحص التفعيل والمتابعة',
                          'Check Activation',
                        ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            ZText.t(
              'ZENQIVO لا يوفر قنوات أو محتوى. المستخدم مسؤول عن المصادر التي يربطها.',
              'ZENQIVO does not provide channels or content. Users are responsible for the sources they connect.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: ZenqivoColors.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityTile extends StatelessWidget {
  const _IdentityTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ZText.t('تم النسخ', 'Copied')),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: ZenqivoColors.surfaceRaised,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF2F2A1A)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: ZenqivoColors.muted,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                SelectableText(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copy(context),
            tooltip: ZText.t('نسخ', 'Copy'),
            icon: const Icon(
              Icons.copy_rounded,
              color: ZenqivoColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0x99111111),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF3B3218)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: ZenqivoColors.gold),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
