import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var notificationChannel: FlutterMethodChannel?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // Register Flutter plugins
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channel for notifications
    guard let controller = window?.rootViewController as? FlutterViewController else {
      fatalError("rootViewController is not type FlutterViewController")
    }
    
    notificationChannel = FlutterMethodChannel(
      name: "nachna/notifications",
      binaryMessenger: controller.binaryMessenger
    )
    
    notificationChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call: call, result: result)
    }
    
    // Setup notification handling
    setupNotifications(application: application, launchOptions: launchOptions)
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupNotifications(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    // Set notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Check if app was launched from notification
    if let userInfo = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Any] {
      // Handle app launch from notification
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.notificationChannel?.invokeMethod("onNotificationTapped", arguments: userInfo)
      }
    }
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "requestPermissionsAndGetToken":
      requestPermissionsAndGetToken(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func requestPermissionsAndGetToken(result: @escaping FlutterResult) {
    // Request notification permissions
    if #available(iOS 10.0, *) {
      let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { granted, error in
          if granted {
            DispatchQueue.main.async {
              UIApplication.shared.registerForRemoteNotifications()
            }
            
            // Wait a bit for token to be received
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              if let token = self.deviceTokenString {
                result([
                  "success": true,
                  "token": token
                ])
              } else {
                result([
                  "success": false,
                  "error": "Failed to get device token"
                ])
              }
            }
          } else {
            result([
              "success": false,
              "error": error?.localizedDescription ?? "Permission denied"
            ])
          }
        }
      )
    } else {
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      UIApplication.shared.registerUserNotificationSettings(settings)
      UIApplication.shared.registerForRemoteNotifications()
      
      // For iOS < 10, assume success
      DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        if let token = self.deviceTokenString {
          result([
            "success": true,
            "token": token
          ])
        } else {
          result([
            "success": false,
            "error": "Failed to get device token"
          ])
        }
      }
    }
  }
  
  private var deviceTokenString: String?
  
  // Handle successful registration for remote notifications
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("📱 APNs Device Token: \(tokenString)")
    
    deviceTokenString = tokenString
    
    // Notify Flutter about token refresh
    notificationChannel?.invokeMethod("onTokenRefresh", arguments: tokenString)
  }
  
  // Handle registration failure
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
    deviceTokenString = nil
  }
  
  // Handle notification when app is in background/terminated
  override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("📨 Background notification received: \(userInfo)")
    
    // Notify Flutter
    notificationChannel?.invokeMethod("onNotificationReceived", arguments: userInfo)
    
    completionHandler(.newData)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  // Handle notifications when app is in foreground
  @available(iOS 10, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("📨 Foreground notification received: \(userInfo)")
    
    // Notify Flutter
    notificationChannel?.invokeMethod("onNotificationReceived", arguments: userInfo)
    
    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }

  // Handle notification tap
  @available(iOS 10, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("📨 Notification tapped: \(userInfo)")
    
    // Notify Flutter
    notificationChannel?.invokeMethod("onNotificationTapped", arguments: userInfo)
    
    completionHandler()
  }
}
