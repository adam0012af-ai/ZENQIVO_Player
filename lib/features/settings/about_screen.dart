import 'package:flutter/material.dart';

import '../../core/config/zenqivo_config.dart';
import '../../core/localization/zenqivo_strings.dart';
import '../../core/theme/zenqivo_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(ZText.t('حول ZENQIVO', 'About ZENQIVO'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2C2410), Color(0xFF090909)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: ZenqivoColors.gold, width: 2),
              ),
              alignment: Alignment.center,
              child: const Text(
                'Z▶',
                style: TextStyle(
                  color: ZenqivoColors.goldSoft,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'ZENQIVO PLAYER',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${ZText.t('الإصدار', 'Version')} ${ZenqivoConfig.version} (${ZenqivoConfig.buildNumber})',
              style: const TextStyle(color: ZenqivoColors.muted),
            ),
          ),
          const SizedBox(height: 28),
          _InfoTile(
            icon: Icons.shield_outlined,
            title: ZText.t('الخصوصية', 'Privacy'),
            body: ZText.t(
              'بيانات المشاهدة والمفضلة والملفات الشخصية تُحفظ محليًا على الجهاز. بيانات اعتماد المصادر تُخزّن مشفرة في خادم ZENQIVO.',
              'Watch history, favorites and profiles are stored locally on the device. Provider credentials are encrypted on the ZENQIVO server.',
            ),
          ),
          _InfoTile(
            icon: Icons.verified_user_outlined,
            title: ZText.t('الاستخدام', 'Usage'),
            body: ZText.t(
              'ZENQIVO Player مشغل وسائط فقط ولا يوفّر قنوات أو أفلام أو اشتراكات محتوى. المستخدم مسؤول عن المصادر التي يربطها وصلاحية استخدامها.',
              'ZENQIVO Player is a media player only. It does not provide channels, movies, or content subscriptions. Users are responsible for connected sources and authorization to use them.',
            ),
          ),
          _InfoTile(
            icon: Icons.description_outlined,
            title: ZText.t('الترخيص', 'License'),
            body: ZText.t(
              'جميع عناصر الهوية والتصميم والكود المخصص في التطبيق تخص مشروع ZENQIVO. مكتبات الطرف الثالث تخضع لتراخيصها الأصلية.',
              'ZENQIVO custom branding, design, and application code belong to the ZENQIVO project. Third-party libraries remain subject to their respective licenses.',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: ZenqivoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF272217)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ZenqivoColors.gold),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 7),
                Text(
                  body,
                  style: const TextStyle(
                    color: ZenqivoColors.muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
