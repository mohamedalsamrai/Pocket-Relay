import Flutter
import UIKit
import UserNotifications

final class BackgroundExecutionCoordinator {
  static let shared = BackgroundExecutionCoordinator()

  private init() {}

  private var finiteBackgroundTask: UIBackgroundTaskIdentifier = .invalid
  private weak var flutterViewController: FlutterViewController?
  private var backgroundExecutionChannel: FlutterMethodChannel?

  func register(with flutterViewController: FlutterViewController) {
    guard self.flutterViewController !== flutterViewController else {
      return
    }

    backgroundExecutionChannel?.setMethodCallHandler(nil)

    let channel = FlutterMethodChannel(
      name: "me.vinch.pocketrelay/background_execution",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleBackgroundExecutionCall(call, result: result)
    }

    self.flutterViewController = flutterViewController
    backgroundExecutionChannel = channel
  }

  private func handleBackgroundExecutionCall(
    _ call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    switch call.method {
    case "setFiniteBackgroundTaskEnabled":
      guard
        let arguments = call.arguments as? [String: Any],
        let enabled = arguments["enabled"] as? Bool
      else {
        result(
          FlutterError(
            code: "invalid-arguments",
            message: "Expected a boolean enabled flag.",
            details: nil
          )
        )
        return
      }

      if enabled {
        beginFiniteBackgroundTaskIfNeeded()
      } else {
        endFiniteBackgroundTaskIfNeeded()
      }
      result(nil)
    case "notificationsPermissionGranted":
      notificationCenter().getNotificationSettings { settings in
        let granted: Bool
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
          granted = true
        default:
          granted = false
        }

        DispatchQueue.main.async {
          result(granted)
        }
      }
    case "requestNotificationPermission":
      notificationCenter().requestAuthorization(
        options: [.alert, .badge, .sound]
      ) { granted, error in
        DispatchQueue.main.async {
          if let error {
            result(
              FlutterError(
                code: "notification-permission-failed",
                message: error.localizedDescription,
                details: nil
              )
            )
            return
          }
          result(granted)
        }
      }
    case "showTurnCompletionNotification":
      guard
        let arguments = call.arguments as? [String: Any],
        let title = (arguments["title"] as? String)?.trimmingCharacters(
          in: .whitespacesAndNewlines
        ),
        !title.isEmpty
      else {
        result(
          FlutterError(
            code: "invalid-arguments",
            message: "Expected a non-empty title.",
            details: nil
          )
        )
        return
      }

      let body = (arguments["body"] as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      postTurnCompletionNotification(title: title, body: body, result: result)
    case "clearTurnCompletionNotification":
      clearTurnCompletionNotification()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func beginFiniteBackgroundTaskIfNeeded() {
    guard finiteBackgroundTask == .invalid else {
      return
    }

    finiteBackgroundTask = UIApplication.shared.beginBackgroundTask(
      withName: "PocketRelayLiveTurn"
    ) { [weak self] in
      self?.endFiniteBackgroundTaskIfNeeded()
    }
  }

  private func endFiniteBackgroundTaskIfNeeded() {
    guard finiteBackgroundTask != .invalid else {
      return
    }

    let task = finiteBackgroundTask
    finiteBackgroundTask = .invalid
    UIApplication.shared.endBackgroundTask(task)
  }

  private func notificationCenter() -> UNUserNotificationCenter {
    UNUserNotificationCenter.current()
  }

  private func postTurnCompletionNotification(
    title: String,
    body: String?,
    result: @escaping FlutterResult
  ) {
    let content = UNMutableNotificationContent()
    content.title = title
    if let body, !body.isEmpty {
      content.body = body
    }
    content.sound = .default

    let request = UNNotificationRequest(
      identifier: turnCompletionNotificationIdentifier,
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    )

    let notificationCenter = notificationCenter()
    notificationCenter.removePendingNotificationRequests(
      withIdentifiers: [turnCompletionNotificationIdentifier]
    )
    notificationCenter.removeDeliveredNotifications(
      withIdentifiers: [turnCompletionNotificationIdentifier]
    )
    notificationCenter.add(request) { error in
      DispatchQueue.main.async {
        if let error {
          result(
            FlutterError(
              code: "notification-post-failed",
              message: error.localizedDescription,
              details: nil
            )
          )
          return
        }

        result(nil)
      }
    }
  }

  private func clearTurnCompletionNotification() {
    let notificationCenter = notificationCenter()
    notificationCenter.removePendingNotificationRequests(
      withIdentifiers: [turnCompletionNotificationIdentifier]
    )
    notificationCenter.removeDeliveredNotifications(
      withIdentifiers: [turnCompletionNotificationIdentifier]
    )
  }

  private let turnCompletionNotificationIdentifier =
    "pocketRelay.turnCompletion"
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
