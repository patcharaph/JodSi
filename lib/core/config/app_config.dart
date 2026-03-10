abstract class AppConfig {
  static const String appName = 'JodSi';
  static const String appNameThai = 'จดสิ';
  static const String appVersion = '2.1.0';

  // Supabase — replace with your project values
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_ANON_KEY',
  );

  // Recording limits
  static const int freeMaxRecordingMinutes = 15;
  static const int proMaxRecordingMinutes = 60;

  // Soft prompt trigger
  static const int softPromptAfterRecordings = 3;

  // Anonymous cleanup threshold (days)
  static const int anonymousCleanupDays = 90;

  // Storage bucket
  static const String audioBucket = 'audio';

  // Admin emails (can access Admin Dashboard)
  static const List<String> adminEmails = [
    'adminjodsi@jodsi.com',
  ];
}
