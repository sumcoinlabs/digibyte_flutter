import 'package:background_fetch/background_fetch.dart';

/// Background Fetch Headless Task for Android
/// This function executes when the app is completely killed (headless mode).
void androidBackgroundFetchHeadlessTask(HeadlessTask task) async {
  String taskId = task.taskId; // Unique identifier for the task
  bool isTimeout = task.timeout;

  if (isTimeout) {
    // Handle the scenario where the task exceeds its execution time limit.
    print("[AndroidBackgroundFetch] Task timed out: $taskId");
    BackgroundFetch.finish(taskId); // Mark the task as finished
    return;
  }

  // Place your background task logic here.
  print("[AndroidBackgroundFetch] Headless task executed: $taskId");

  // Notify BackgroundFetch that the task is complete.
  BackgroundFetch.finish(taskId);
}

/// Initialize Android Background Fetch
/// This function configures and starts Background Fetch for periodic tasks.
Future<void> initAndroidBackgroundFetch() async {
  try {
    // Configure the Background Fetch plugin.
    await BackgroundFetch.configure(
      BackgroundFetchConfig(
        minimumFetchInterval: 15, // Minimum interval (in minutes) to run the task
        stopOnTerminate: false,   // Continue tasks after the app is terminated
        startOnBoot: true,        // Restart tasks after device reboot
        enableHeadless: true,     // Allow tasks to run in headless mode (no UI)
      ),
      (String taskId) async {
        // This callback is triggered when the app is in the foreground.
        print("[AndroidBackgroundFetch] Foreground task executed: $taskId");

        // Place your foreground task logic here.

        // Mark the task as complete.
        BackgroundFetch.finish(taskId);
      },
    );

    // Register the headless task for execution when the app is terminated.
    BackgroundFetch.registerHeadlessTask(androidBackgroundFetchHeadlessTask);

    print("[AndroidBackgroundFetch] Initialized successfully.");
  } catch (e) {
    // Handle any errors that occur during initialization.
    print("[AndroidBackgroundFetch] Initialization error: $e");
  }
}
