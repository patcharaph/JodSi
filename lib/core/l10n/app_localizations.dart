import 'package:flutter/material.dart';

enum AppLanguage { th, en }

class AppLocalizations {
  final AppLanguage language;

  const AppLocalizations({this.language = AppLanguage.th});

  Locale get locale => language == AppLanguage.th
      ? const Locale('th')
      : const Locale('en');

  String get languageLabel =>
      language == AppLanguage.th ? 'ภาษาไทย' : 'English';

  // ─── General ──────────────────────────────────────
  String get appTitle => 'JodSi';
  String get note => _t('โน้ต', 'Note');
  String get loading => _t('กำลังโหลด...', 'Loading...');
  String get error => _t('เกิดข้อผิดพลาด', 'An error occurred');
  String errorWith(String e) => _t('เกิดข้อผิดพลาด: $e', 'Error: $e');
  String get cancel => _t('ยกเลิก', 'Cancel');
  String get delete => _t('ลบ', 'Delete');
  String get retry => _t('ลองใหม่', 'Retry');
  String get goHome => _t('กลับหน้าหลัก', 'Go Home');

  // ─── Recorder Screen ──────────────────────────────
  String get notesHistory => _t('ประวัติโน้ต', 'Notes History');
  String get settings => _t('ตั้งค่า', 'Settings');
  String get tapToRecord => _t('แตะเพื่อเริ่มอัดเสียง', 'Tap to start recording');
  String get recording => _t('กำลังอัดเสียง...', 'Recording...');
  String get uploading => _t('กำลังอัพโหลด...', 'Uploading...');
  String get processing => _t('กำลังประมวลผล...', 'Processing...');
  String bookmarksCount(int count) =>
      _t('📌 $count บุ๊คมาร์ค', '📌 $count bookmark${count > 1 ? "s" : ""}');
  String get addBookmark => _t('เพิ่มบุ๊คมาร์ค', 'Add Bookmark');
  String get noRecordPermission =>
      _t('ไม่ได้รับสิทธิ์ในการอัดเสียง', 'Microphone permission denied');

  // ─── Processing Screen ────────────────────────────
  String get processingTitle => _t('กำลังประมวลผล', 'Processing');
  String get noteNotFound => _t('ไม่พบโน้ต', 'Note not found');
  String get processingError =>
      _t('เกิดข้อผิดพลาดในการประมวลผล', 'Processing failed');
  String get uploadingAudio => _t('กำลังอัพโหลดเสียง', 'Uploading Audio');
  String get transcribing => _t('กำลังถอดความ', 'Transcribing');
  String get summarizingAI => _t('กำลังสรุปด้วย AI', 'Summarizing with AI');
  String get uploadingDesc =>
      _t('อัพโหลดไฟล์เสียงไปยังเซิร์ฟเวอร์', 'Uploading audio to server');
  String get transcribingDesc =>
      _t('Deepgram กำลังถอดเสียงเป็นข้อความ\nอาจใช้เวลาสักครู่',
          'Deepgram is transcribing audio to text\nThis may take a moment');
  String get summarizingDesc =>
      _t('AI กำลังสรุปเนื้อหาให้คุณ', 'AI is summarizing your content');
  String get pleaseWait => _t('กรุณารอสักครู่...', 'Please wait...');
  String duration(String formatted) =>
      _t('ความยาว: $formatted', 'Duration: $formatted');
  String get stepUpload => _t('อัพโหลด', 'Upload');
  String get stepTranscribe => _t('ถอดความ', 'Transcribe');
  String get stepSummarize => _t('สรุป AI', 'AI Summary');

  // ─── Notes List Screen ────────────────────────────
  String get allNotes => _t('โน้ตทั้งหมด', 'All Notes');
  String get noNotesYet => _t('ยังไม่มีโน้ต', 'No notes yet');
  String get startRecordingPrompt =>
      _t('เริ่มอัดเสียงเพื่อสร้างโน้ตแรกของคุณ',
          'Start recording to create your first note');
  String get recordVoice => _t('อัดเสียง', 'Record');
  String get badgeUploading => _t('อัพโหลด', 'Uploading');
  String get badgeTranscribing => _t('ถอดความ', 'Transcribing');
  String get badgeSummarizing => _t('สรุป', 'Summarizing');
  String get badgeProcessing => _t('ประมวลผล', 'Processing');

  // ─── Note Detail Screen ───────────────────────────
  String get copy => _t('คัดลอก', 'Copy');
  String get copiedSummary => _t('คัดลอกสรุปแล้ว ✓', 'Summary copied ✓');
  String get tabSummary => _t('สรุป', 'Summary');
  String get tabTranscript => _t('ถอดความ', 'Transcript');
  String get noSummaryYet => _t('ยังไม่มีสรุป', 'No summary yet');
  String get noTranscriptYet =>
      _t('ยังไม่มีข้อความถอดเสียง', 'No transcript yet');
  String get deleteNoteTitle => _t('ลบโน้ต?', 'Delete Note?');
  String get deleteNoteMessage =>
      _t('คุณต้องการลบโน้ตนี้ใช่หรือไม่? ไม่สามารถกู้คืนได้',
          'Are you sure you want to delete this note? This cannot be undone.');
  String get sectionDetail => _t('รายละเอียด', 'Detail');

  // ─── Settings Screen ──────────────────────────────
  String get anonymousUser => _t('ผู้ใช้ไม่ระบุชื่อ', 'Anonymous User');
  String get linkAccount => _t('เชื่อมบัญชี', 'Link Account');
  String get usage => _t('การใช้งาน', 'Usage');
  String get plan => _t('แพลน', 'Plan');
  String get limitPerSession => _t('จำกัดต่อครั้ง', 'Limit per session');
  String minutes(dynamic n) => _t('$n นาที', '$n min');
  String get usedThisMonth => _t('ใช้ไปเดือนนี้', 'Used this month');
  String get cannotLoadData =>
      _t('ไม่สามารถโหลดข้อมูลได้', 'Failed to load data');
  String get anonymousWarning =>
      _t('คุณยังไม่ได้เชื่อมบัญชี หากลบแอปหรือเปลี่ยนเครื่อง โน้ตทั้งหมดจะหายไป',
          'Your account is not linked. If you uninstall the app or switch devices, all notes will be lost.');
  String get version => _t('เวอร์ชัน', 'Version');
  String get signOut => _t('ออกจากระบบ', 'Sign Out');
  String get signOutTitle => _t('ออกจากระบบ?', 'Sign Out?');
  String get signOutMessage =>
      _t('หากคุณเป็นผู้ใช้ Anonymous ข้อมูลทั้งหมดจะหายไป',
          'If you are an anonymous user, all data will be lost.');
  String get languageSetting => _t('ภาษา', 'Language');

  // ─── Link Account Sheet ───────────────────────────
  String get linkAccountTitle =>
      _t('เชื่อมบัญชีของคุณ', 'Link Your Account');
  String get linkAccountDesc =>
      _t('เชื่อมบัญชีเพื่อเก็บโน้ตข้ามเครื่อง\nและไม่สูญเสียข้อมูลเมื่อเปลี่ยนเครื่อง',
          'Link your account to sync notes across devices\nand prevent data loss when switching devices');
  String get loginWithLine => _t('เข้าสู่ระบบด้วย LINE', 'Sign in with LINE');
  String get loginWithGoogle =>
      _t('เข้าสู่ระบบด้วย Google', 'Sign in with Google');
  String get skipForNow => _t('ข้ามไปก่อน', 'Skip for now');
  String get loginWithEmail =>
      _t('เข้าสู่ระบบด้วย Email', 'Sign in with Email');
  String get emailLabel => _t('อีเมล', 'Email');
  String get passwordLabel => _t('รหัสผ่าน', 'Password');
  String get emailPasswordRequired =>
      _t('กรุณากรอกอีเมลและรหัสผ่าน', 'Please enter email and password');
  String emailLoginError(String e) =>
      _t('เข้าสู่ระบบไม่สำเร็จ: $e', 'Sign in failed: $e');
  String get back => _t('กลับ', 'Back');
  String lineLoginError(String e) =>
      _t('LINE Login ยังไม่พร้อมใช้งาน: $e', 'LINE Login not available: $e');
  String googleLoginError(String e) =>
      _t('Google Login ยังไม่พร้อมใช้งาน: $e',
          'Google Login not available: $e');

  // ─── Feedback ────────────────────────────────────────
  String get feedbackTitle => _t('ส่งความคิดเห็น', 'Send Feedback');
  String get feedbackDesc =>
      _t('ช่วยเราพัฒนาแอปให้ดียิ่งขึ้น', 'Help us improve the app');
  String get feedbackRating => _t('ให้คะแนน', 'Rate');
  String get feedbackHint =>
      _t('เขียนความคิดเห็น...', 'Write your feedback...');
  String get feedbackSubmit => _t('ส่ง', 'Submit');
  String get feedbackThanks =>
      _t('ขอบคุณสำหรับความคิดเห็น!', 'Thanks for your feedback!');
  String get feedback => _t('ส่ง Feedback', 'Send Feedback');
  String get adminDashboard => _t('Admin Dashboard', 'Admin Dashboard');

  // ─── Delete ─────────────────────────────────────────
  String get selectNotes => _t('เลือกโน้ต', 'Select Notes');
  String selectedCount(int n) => _t('เลือก $n รายการ', '$n selected');
  String get deleteSelected =>
      _t('ลบที่เลือก', 'Delete Selected');
  String deleteMultipleMessage(int n) =>
      _t('ต้องการลบ $n โน้ตที่เลือกหรือไม่?\nจะลบทั้งเสียงและข้อมูลถอดความ',
          'Delete $n selected notes?\nThis will also delete audio and transcripts');
  String get noteDeleted => _t('ลบโน้ตแล้ว', 'Note deleted');
  String notesDeleted(int n) => _t('ลบ $n โน้ตแล้ว', '$n notes deleted');

  // ─── Model fallbacks ──────────────────────────────
  String get untitledNote => _t('โน้ตไม่มีชื่อ', 'Untitled Note');

  // ─── Helper ───────────────────────────────────────
  String _t(String th, String en) => language == AppLanguage.th ? th : en;
}
