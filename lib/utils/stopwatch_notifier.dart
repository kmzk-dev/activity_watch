// lib/utils/stopwatch_notifier.dart
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class StopwatchNotifier {
  static const String _notificationChannelId = 'activity_watch_timer_channel';
  static const String _notificationChannelName = 'Activity Watch Timer';
  static const String _notificationChannelDesc = 'Notification when stopwatch is running.';

  static bool _isServiceInitialized = false;
  static bool _isNotificationCurrentlyShown = false; // App's perception of notification state

  // Helper function to format elapsedTime to HH:MM:SS for notification
  static String _formatTimeForNotification(String fullElapsedTime) {
    // "hh:mm:ss:ms" からミリ秒部分を除去
    List<String> parts = fullElapsedTime.split(':');
    if (parts.length == 4) {
      return '${parts[0]}:${parts[1]}:${parts[2]}'; // hh:mm:ss
    }
    return fullElapsedTime; //予期しない形式の場合はそのまま返す
  }

  static Future<void> initializeService() async {
    if (_isServiceInitialized || kIsWeb) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: _notificationChannelId,
        channelName: _notificationChannelName,
        channelDescription: _notificationChannelDesc,
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
        enableVibration: false,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000), 
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
    _isServiceInitialized = true;
    // print('StopwatchNotifier: Service initialized with eventAction repeat(1000).');
  }

  static Future<void> _ensureNotificationIsOngoing(String title, String text) async {
    if (!_isServiceInitialized || kIsWeb) {
      // print('StopwatchNotifier._ensureNotificationIsOngoing: Not initialized or web. Text: $text');
      return;
    }

    // ★★★ 変更点: 通知用の時間文字列をフォーマット ★★★
    final String notificationText = _formatTimeForNotification(text);

    try {
      bool isCurrentlyRunning = await FlutterForegroundTask.isRunningService;
      // print('StopwatchNotifier._ensureNotificationIsOngoing: isRunningService = $isCurrentlyRunning. Attempting to show/update with Text: $notificationText (Original: $text)');

      if (isCurrentlyRunning) {
        // print('StopwatchNotifier._ensureNotificationIsOngoing: Service is running, calling updateService. Text: $notificationText');
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: notificationText, // フォーマットされた文字列を使用
        );
        // print('StopwatchNotifier._ensureNotificationIsOngoing: updateService CALLED. Text: $notificationText');
      } else {
        // print('StopwatchNotifier._ensureNotificationIsOngoing: Service NOT running, calling startService. Text: $notificationText');
        await FlutterForegroundTask.startService(
          notificationTitle: title,
          notificationText: notificationText, // フォーマットされた文字列を使用
        );
        // print('StopwatchNotifier._ensureNotificationIsOngoing: startService CALLED. Text: $notificationText');
      }
      _isNotificationCurrentlyShown = true;
    } catch (e) {
      // print('StopwatchNotifier: Error in _ensureNotificationIsOngoing with Text $notificationText (Original: $text): $e');
      _isNotificationCurrentlyShown = false;
    }
  }

  static Future<void> startNotification(String elapsedTime) async {
    // print('StopwatchNotifier.startNotification called with elapsedTime: $elapsedTime');
    if (!_isServiceInitialized || kIsWeb) {
      // print('StopwatchNotifier.startNotification: Not initialized or web.');
      return;
    }
    await _ensureNotificationIsOngoing('ストップウォッチ実行中', elapsedTime);
  }

  static Future<void> updateNotification(String elapsedTime) async {
    if (!_isServiceInitialized || kIsWeb) {
      return;
    }

    bool isRunning = await FlutterForegroundTask.isRunningService;
    // print('StopwatchNotifier.updateNotification: isRunningService = $isRunning. Current _isNotificationCurrentlyShown = $_isNotificationCurrentlyShown');

    if (isRunning) {
        await _ensureNotificationIsOngoing('ストップウォッチ実行中', elapsedTime);
    } else {
        if (_isNotificationCurrentlyShown) {
            // print('StopwatchNotifier.updateNotification: Service NOT running, but _isNotificationCurrentlyShown was true. Resetting flag and attempting to stop (just in case).');
            await stopNotification();
        }
    }
  }

  static Future<void> stopNotification() async {
    // print('StopwatchNotifier.stopNotification called.');
    if (!_isServiceInitialized || kIsWeb) {
      if (!kIsWeb && !_isServiceInitialized) {
        // print('StopwatchNotifier.stopNotification: Not initialized.');
      }
      if (_isNotificationCurrentlyShown) _isNotificationCurrentlyShown = false;
      return;
    }

    bool isRunning = await FlutterForegroundTask.isRunningService;
    // print('StopwatchNotifier.stopNotification: isRunningService = $isRunning. Current _isNotificationCurrentlyShown = $_isNotificationCurrentlyShown');

    if (isRunning) {
      try {
        // print('StopwatchNotifier.stopNotification: Calling FlutterForegroundTask.stopService()');
        await FlutterForegroundTask.stopService();
        _isNotificationCurrentlyShown = false;
        // print('StopwatchNotifier.stopNotification: Notification service stopped successfully via stopService().');
      } catch (e) {
        // print('StopwatchNotifier.stopNotification: Error stopping notification service: $e');
        _isNotificationCurrentlyShown = false;
      }
    } else {
      // print('StopwatchNotifier.stopNotification: Service was not running according to isRunningService. Ensuring flag is false.');
      _isNotificationCurrentlyShown = false;
    }
  }
}
