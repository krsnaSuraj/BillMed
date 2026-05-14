import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(const InitializationSettings(android: androidSettings, iOS: iosSettings));

    // Create notification channel
    const channel = AndroidNotificationChannel(
      'overdue_bills',
      'Overdue Bills',
      description: 'Notifications for overdue bills',
      importance: Importance.high,
    );
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> checkAndNotify(BillMedDatabase db) async {
    try {
      final allBills = await db.getAllBills();
      if (allBills.isEmpty) return;

      final paidMap = await db.getTotalPaidForBills(allBills.map((b) => b.id).toList());
      final overdue = allBills.where((b) {
        final paid = paidMap[b.id] ?? 0.0;
        return paid <= 0 && DateTime.now().difference(b.billDate).inDays > 30;
      }).toList();

      if (overdue.isEmpty) return;

      final totalAmount = overdue.fold<double>(0, (s, b) => s + b.amount);
      final message = overdue.length == 1
          ? '1 bill of ₹${totalAmount.toStringAsFixed(0)} is overdue'
          : '${overdue.length} bills totalling ₹${totalAmount.toStringAsFixed(0)} are overdue';

      await _plugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647).abs(), // unique ID
        'Overdue Bills Reminder',
        message,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'overdue_bills',
            'Overdue Bills',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {}
  }
}
