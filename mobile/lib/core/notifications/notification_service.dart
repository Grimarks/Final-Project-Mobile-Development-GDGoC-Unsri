import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// notif lokal buat 2 hal: reminder task deadline, sama penanda sesi pomodoro
// kelar (kepake kalo app lagi di-background). id dipisah biar gak tabrakan
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _sessionNotificationId = 999999; // cuma 1 slot, sesi aktif kan cuma 1
  static int _taskNotificationId(int taskId) => 100000 + taskId;

  Future<void> _ensureReady() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(const InitializationSettings(android: android, iOS: ios));
    _ready = true;
  }

  // TZDateTime.from pake instant absolut dari dateTime apa adanya, jadi tetep
  // bener walau tz.local belum ke-set ke zona asli device — gausah plugin tambahan
  tz.TZDateTime _asTz(DateTime dateTime) => tz.TZDateTime.from(dateTime, tz.local);

  Future<void> scheduleTaskDueReminder({
    required int taskId,
    required String title,
    required DateTime dueDate,
  }) async {
    if (dueDate.isBefore(DateTime.now())) return; // udah lewat, ngapain dijadwalin
    await _ensureReady();
    await _plugin.zonedSchedule(
      _taskNotificationId(taskId),
      'Task due: $title',
      "It's due now — don't forget to wrap it up.",
      _asTz(dueDate),
      const NotificationDetails(
        android: AndroidNotificationDetails('task_due', 'Task due reminders'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelTaskDueReminder(int taskId) => _plugin.cancel(_taskNotificationId(taskId));

  Future<void> scheduleSessionEndReminder(Duration after) async {
    await _ensureReady();
    await _plugin.zonedSchedule(
      _sessionNotificationId,
      'Focus session complete',
      'Great job! Come back to log how it went.',
      _asTz(DateTime.now().add(after)),
      const NotificationDetails(
        android: AndroidNotificationDetails('session_end', 'Study session reminders'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelSessionEndReminder() => _plugin.cancel(_sessionNotificationId);
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
