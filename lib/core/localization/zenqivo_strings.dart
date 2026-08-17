import 'app_locale_controller.dart';

abstract final class ZText {
  static bool get ar => AppLocaleController.instance.isArabic;

  static String t(String arabic, String english) => ar ? arabic : english;

  static String get home => t('الرئيسية', 'Home');
  static String get live => t('مباشر', 'Live');
  static String get movies => t('أفلام', 'Movies');
  static String get series => t('مسلسلات', 'Series');
  static String get favorites => t('المفضلة', 'Favorites');
  static String get watching => t('المشاهدة', 'Watching');
  static String get settings => t('الإعدادات', 'Settings');
  static String get profiles => t('الملفات الشخصية', 'Profiles');
  static String get chooseProfile => t('من يشاهد الآن؟', 'Who is watching?');
  static String get addProfile => t('إضافة ملف شخصي', 'Add Profile');
  static String get language => t('اللغة', 'Language');
  static String get arabic => 'العربية';
  static String get english => 'English';
  static String get search => t('بحث', 'Search');
  static String get continueWatching => t('متابعة المشاهدة', 'Continue Watching');
  static String get recentlyWatched => t('شاهدت مؤخرًا', 'Recently Watched');
  static String get recentlyAdded => t('المضاف حديثًا', 'Recently Added');
}
