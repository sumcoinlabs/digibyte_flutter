import 'periodic_reminder_item.dart';

class AvailablePeriodicReminderItems {
  static final Map<String, PeriodicReminderItem> availableReminderItems = {
    /*
    // Uncomment the following section to enable the donation reminder
    'donate': PeriodicReminderItem(
      id: 'donate',
      title: 'periodic_reminder_donate_title',
      body: 'periodic_reminder_donate_body',
      button: 'periodic_reminder_backup_button',
    ),
    */
    'backup': PeriodicReminderItem(
      id: 'backup',
      title: 'periodic_reminder_backup_title',
      body: 'periodic_reminder_backup_body',
      button: 'jail_dialog_button',
    ),
  };
}
