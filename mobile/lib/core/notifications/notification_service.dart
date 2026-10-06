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
  static const _testNotificationId = 999998;
  // versi lama cuma 1 notif per task (pas deadline), id-nya masih dibatalin
  // biar pengingat dari install sebelumnya gak nyangkut
  static int _legacyTaskNotificationId(int taskId) => 100000 + taskId;
  // 3 slot per task: H-1 hari, H-1 jam, pas deadline. range-nya jauh di atas
  // id plan/sesi biar gak tabrakan
  static int _taskNotificationId(int taskId, int slot) => 1000000 + taskId * 3 + slot;
  static const _taskReminderOffsets = [Duration(days: 1), Duration(hours: 1), Duration.zero];
  // sesi plan yg di-accept: 200000 + urutan blok (plan cuma 1 aktif per hari)
  static const _planSessionBaseId = 200000;
  static const _planSessionMaxId = 299999;

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
    // Android 13+ gak otomatis nanya izin notif kayak iOS, mesti diminta manual
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  // dipanggil pas app start biar popup izin notif muncul di awal,
  // bukan tiba2 pas lagi bikin task
  Future<void> init() => _ensureReady();

  // TZDateTime.from pake instant absolut dari dateTime apa adanya, jadi tetep
  // bener walau tz.local belum ke-set ke zona asli device — gausah plugin tambahan
  tz.TZDateTime _asTz(DateTime dateTime) => tz.TZDateTime.from(dateTime, tz.local);

  // pengingat bertahap biar sempet dikerjain: H-1 hari, H-1 jam, terus pas
  // deadline. slot yg waktunya udah lewat di-skip
  Future<void> scheduleTaskDueReminder({
    required int taskId,
    required String title,
    required DateTime dueDate,
  }) async {
    final now = DateTime.now();
    if (dueDate.isBefore(now)) return; // udah lewat, ngapain dijadwalin
    await _ensureReady();
    for (var slot = 0; slot < _taskReminderOffsets.length; slot++) {
      final offset = _taskReminderOffsets[slot];
      final fireAt = dueDate.subtract(offset);
      if (!fireAt.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        _taskNotificationId(taskId, slot),
        switch (slot) {
          0 => 'Due tomorrow: $title',
          1 => 'Due in 1 hour: $title',
          _ => 'Task due: $title',
        },
        offset == Duration.zero
            ? "It's due now — don't forget to wrap it up."
            : 'Start now so you finish on time.',
        _asTz(fireAt),
        const NotificationDetails(
          android: AndroidNotificationDetails('task_due', 'Task due reminders'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  Future<void> cancelTaskDueReminder(int taskId) async {
    await _plugin.cancel(_legacyTaskNotificationId(taskId));
    for (var slot = 0; slot < _taskReminderOffsets.length; slot++) {
      await _plugin.cancel(_taskNotificationId(taskId, slot));
    }
  }

  // pengingat tiap sesi dari plan yg di-accept, muncul pas jam mulainya. pengingat
  // plan sebelumnya dibatalin dulu biar gak dobel kalo accept plan lain
  Future<void> schedulePlanSessionReminders(List<PlanSessionReminder> sessions) async {
    await _ensureReady();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.id >= _planSessionBaseId && request.id <= _planSessionMaxId) {
        await _plugin.cancel(request.id);
      }
    }
    final now = DateTime.now();
    for (var i = 0; i < sessions.length; i++) {
      final session = sessions[i];
      if (!session.start.isAfter(now)) continue; // sesinya udah lewat
      await _plugin.zonedSchedule(
        _planSessionBaseId + i,
        'Study session starting: ${session.title}',
        session.timeLabel,
        _asTz(session.start),
        const NotificationDetails(
          android: AndroidNotificationDetails('plan_session', 'Study plan reminders'),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

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

  Future<void> cancelAll() async {
    await _ensureReady();
    await _plugin.cancelAll();
  }

  // tombol "test notification" di Profile, buat ngecek/demo notif tanpa nunggu deadline
  Future<void> scheduleTestNotification(Duration after) async {
    await _ensureReady();
    await _plugin.zonedSchedule(
      _testNotificationId,
      'CampusFlow reminder',
      'Notifications are working — you will be reminded before deadlines.',
      _asTz(DateTime.now().add(after)),
      const NotificationDetails(
        android: AndroidNotificationDetails('test', 'Test notifications'),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class PlanSessionReminder {
  const PlanSessionReminder({required this.title, required this.start, required this.timeLabel});

  final String title;
  final DateTime start;
  final String timeLabel; // "10:00–11:00", jadi isi notifnya
}

final notificationServiceProvider = Provider<NotificationService>((ref) => NotificationService());
