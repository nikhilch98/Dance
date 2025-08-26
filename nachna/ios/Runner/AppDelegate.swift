import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var notificationChannel: FlutterMethodChannel?
  private var deviceTokenString: String?
  private var permissionStatusObserver: NSObjectProtocol?
  private var deepLinkChannel: FlutterMethodChannel?
  private var instagramShareChannel: FlutterMethodChannel?
  // Deduplicate rapid duplicate deep link deliveries from iOS
  private var lastDeepLinkUrl: String?
  private var lastDeepLinkAt: Date?
  
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
    
    // Monitor app lifecycle for permission changes
    setupPermissionStatusMonitoring()
    
    // Set up deep link method channel
    deepLinkChannel = FlutterMethodChannel(name: "nachna/deep_links", binaryMessenger: controller.binaryMessenger)
    
    setupDeepLinkMethodChannel()

    // Set up Instagram share method channel
    instagramShareChannel = FlutterMethodChannel(name: "nachna/instagram_share", binaryMessenger: controller.binaryMessenger)
    setupInstagramShareMethodChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupPermissionStatusMonitoring() {
    // Monitor when app becomes active (user might have changed settings)
    NotificationCenter.default.addObserver(
      forName: UIApplication.didBecomeActiveNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.checkPermissionStatusOnAppActivation()
    }
    
    // Monitor when app enters foreground
    NotificationCenter.default.addObserver(
      forName: UIApplication.willEnterForegroundNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      // Delay check to allow the app to fully activate
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        self?.checkPermissionStatusOnAppActivation()
      }
    }
  }
  
  private func checkPermissionStatusOnAppActivation() {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
        DispatchQueue.main.async {
          switch settings.authorizationStatus {
          case .authorized, .provisional:
            // Permissions are granted - try to get token if we don't have one
            if self?.deviceTokenString == nil {
              print("📱 Permissions granted but no token - registering for remote notifications")
              UIApplication.shared.registerForRemoteNotifications()
            } else {
              // Re-register existing token with server (in case registration failed before)
              print("📱 Permissions granted and token exists - notifying Flutter")
              self?.notifyFlutterOfPermissionChange(granted: true, token: self?.deviceTokenString)
            }
            
          case .denied:
            // User has explicitly denied - notify Flutter
            print("📱 Permissions denied - notifying Flutter")
            self?.notifyFlutterOfPermissionChange(granted: false, token: nil)
            
          case .notDetermined:
            // User hasn't been asked yet - this is normal on first launch
            print("📱 Permissions not determined yet")
            break
            
          case .ephemeral:
            // App Clips - treat as authorized
            if self?.deviceTokenString == nil {
              UIApplication.shared.registerForRemoteNotifications()
            }
            
          @unknown default:
            print("⚠️ Unknown notification authorization status")
          }
        }
      }
    } else {
      // iOS < 10 - check if registered for remote notifications
      let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
      print("📱 iOS < 10 - isRegisteredForRemoteNotifications: \(isRegistered)")
      self.notifyFlutterOfPermissionChange(granted: isRegistered, token: self.deviceTokenString)
    }
  }
  
  private func notifyFlutterOfPermissionChange(granted: Bool, token: String?) {
    notificationChannel?.invokeMethod("onPermissionStatusChanged", arguments: [
      "granted": granted,
      "token": token as Any
    ])
  }
  
  private func setupNotifications(application: UIApplication, launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
    // Set notification delegate
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    
    // Check if app was launched from notification
    if let userInfo = launchOptions?[UIApplication.LaunchOptionsKey.remoteNotification] as? [String: Any] {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        self.notificationChannel?.invokeMethod("onNotificationTapped", arguments: userInfo)
      }
    }
    
    // Always try to register for remote notifications on app start
    // (this will work if permissions were granted in Settings)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      self.checkPermissionStatusOnAppActivation()
    }
  }
  
  private func handleMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "initialize":
      initializeNotifications(result: result)
    case "requestPermissionsAndGetToken":
      requestPermissionsAndGetToken(result: result)
    case "checkPermissionStatus":
      checkCurrentPermissionStatus(result: result)
    case "openNotificationSettings":
      openNotificationSettings(result: result)
    case "retryTokenRegistration":
      retryTokenRegistration(result: result)
    case "isRegisteredForNotifications":
      isRegisteredForNotifications(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
  
  private func checkCurrentPermissionStatus(result: @escaping FlutterResult) {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          let status = settings.authorizationStatus
          result([
            "status": self.authorizationStatusToString(status),
            "canRequest": status == .notDetermined,
            "token": self.deviceTokenString as Any,
            "isRegistered": UIApplication.shared.isRegisteredForRemoteNotifications
          ])
        }
      }
    } else {
      // For iOS < 10, check if registered
      let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
      result([
        "status": isRegistered ? "authorized" : "denied",
        "canRequest": !isRegistered,
        "token": self.deviceTokenString as Any,
        "isRegistered": isRegistered
      ])
    }
  }
  
  private func openNotificationSettings(result: @escaping FlutterResult) {
    if #available(iOS 10.0, *) {
      if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
        UIApplication.shared.open(settingsUrl) { success in
          result(success)
        }
      } else {
        result(false)
      }
    } else {
      result(false)
    }
  }
  
  private func retryTokenRegistration(result: @escaping FlutterResult) {
    // Force re-registration for remote notifications
    UIApplication.shared.registerForRemoteNotifications()
    
    // Wait for token to be received
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
      result([
        "success": self.deviceTokenString != nil,
        "token": self.deviceTokenString as Any
      ])
    }
  }
  
  private func initializeNotifications(result: @escaping FlutterResult) {
    print("📱 Initialize notifications called from Flutter")
    
    // Check current permission status and return token if available
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
          
          print("📱 Current authorization status: \(self.authorizationStatusToString(settings.authorizationStatus))")
          print("📱 Device token available: \(self.deviceTokenString != nil)")
          
          if isAuthorized && self.deviceTokenString == nil {
            // Authorized but no token - try to get one
            print("📱 Authorized but no token - registering for remote notifications")
            UIApplication.shared.registerForRemoteNotifications()
            
            // Wait a bit for token to be received
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
              result([
                "success": true,
                "deviceToken": self.deviceTokenString as Any,
                "isAuthorized": isAuthorized,
                "authorizationStatus": self.authorizationStatusToString(settings.authorizationStatus)
              ])
            }
          } else {
            // Return current status
            result([
              "success": true,
              "deviceToken": self.deviceTokenString as Any,
              "isAuthorized": isAuthorized,
              "authorizationStatus": self.authorizationStatusToString(settings.authorizationStatus)
            ])
          }
        }
      }
    } else {
      // iOS < 10
      let isRegistered = UIApplication.shared.isRegisteredForRemoteNotifications
      if isRegistered && self.deviceTokenString == nil {
        UIApplication.shared.registerForRemoteNotifications()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          result([
            "success": true,
            "deviceToken": self.deviceTokenString as Any,
            "isAuthorized": isRegistered,
            "authorizationStatus": isRegistered ? "authorized" : "denied"
          ])
        }
      } else {
        result([
          "success": true,
          "deviceToken": self.deviceTokenString as Any,
          "isAuthorized": isRegistered,
          "authorizationStatus": isRegistered ? "authorized" : "denied"
        ])
      }
    }
  }
  
  private func isRegisteredForNotifications(result: @escaping FlutterResult) {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          let isAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
          result(isAuthorized && UIApplication.shared.isRegisteredForRemoteNotifications)
        }
      }
    } else {
      result(UIApplication.shared.isRegisteredForRemoteNotifications)
    }
  }
  
  @available(iOS 10.0, *)
  private func authorizationStatusToString(_ status: UNAuthorizationStatus) -> String {
    switch status {
    case .notDetermined: return "notDetermined"
    case .denied: return "denied"
    case .authorized: return "authorized"
    case .provisional: return "provisional"
    case .ephemeral: return "ephemeral"
    @unknown default: return "unknown"
    }
  }
  
  private func requestPermissionsAndGetToken(result: @escaping FlutterResult) {
    if #available(iOS 10.0, *) {
      // First check current status
      UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
        DispatchQueue.main.async {
          switch settings.authorizationStatus {
          case .authorized, .provisional:
            // Already authorized - just get token
            print("📱 Already authorized - registering for remote notifications")
            UIApplication.shared.registerForRemoteNotifications()
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
              result([
                "success": true,
                "token": self?.deviceTokenString as Any,
                "wasAlreadyAuthorized": true,
                "shouldOpenSettings": false
              ])
            }
            
          case .denied:
            // Previously denied - can't request again, must go to Settings
            print("📱 Previously denied - directing to Settings")
            result([
              "success": false,
              "error": "Notifications previously denied. Please enable in Settings.",
              "shouldOpenSettings": true,
              "wasAlreadyAuthorized": false,
              "token": NSNull()
            ])
            
          case .notDetermined:
            // Can request permission
            print("📱 Requesting permission for first time")
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
              options: authOptions,
              completionHandler: { granted, error in
                DispatchQueue.main.async {
                  if granted {
                    print("📱 Permission granted - registering for remote notifications")
                    UIApplication.shared.registerForRemoteNotifications()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                      result([
                        "success": true,
                        "token": self?.deviceTokenString as Any,
                        "wasAlreadyAuthorized": true,
                        "shouldOpenSettings": false
                      ])
                    }
                  } else {
                    print("📱 Permission denied by user")
                    result([
                      "success": false,
                      "error": error?.localizedDescription ?? "Permission denied",
                      "shouldOpenSettings": false,
                      "wasAlreadyAuthorized": false,
                      "token": NSNull()
                    ])
                  }
                }
              }
            )
            
          default:
            result([
              "success": false,
              "error": "Unknown authorization status",
              "shouldOpenSettings": false,
              "wasAlreadyAuthorized": false,
              "token": NSNull()
            ])
          }
        }
      }
    } else {
      // iOS < 10 handling
      print("📱 iOS < 10 - registering for notifications")
      let settings = UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      UIApplication.shared.registerUserNotificationSettings(settings)
      UIApplication.shared.registerForRemoteNotifications()
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
        result([
          "success": self.deviceTokenString != nil,
          "token": self.deviceTokenString as Any,
          "wasAlreadyAuthorized": false,
          "shouldOpenSettings": false
        ])
      }
    }
  }
  
  // Handle successful registration for remote notifications
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    print("📱 APNs Device Token: \(tokenString)")
    
    let wasNewToken = deviceTokenString != tokenString
    deviceTokenString = tokenString
    
    // Always notify Flutter when we get a token (new or refreshed)
    notificationChannel?.invokeMethod("onTokenRefresh", arguments: [
      "token": tokenString,
      "isNewToken": wasNewToken
    ])
  }
  
  // Handle registration failure
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error)")
    deviceTokenString = nil
    
    notificationChannel?.invokeMethod("onRegistrationError", arguments: [
      "error": error.localizedDescription
    ])
  }
  
  // Handle notification when app is in background/terminated
  override func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    print("📨 Background notification received: \(userInfo)")
    
    notificationChannel?.invokeMethod("onNotificationReceived", arguments: userInfo)
    completionHandler(.newData)
  }
  
  // MARK: - UNUserNotificationCenterDelegate
  
  @available(iOS 10, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let userInfo = notification.request.content.userInfo
    print("📨 Foreground notification received: \(userInfo)")
    
    notificationChannel?.invokeMethod("onNotificationReceived", arguments: userInfo)
    
    if #available(iOS 14.0, *) {
      completionHandler([[.banner, .sound, .badge]])
    } else {
      completionHandler([[.alert, .sound, .badge]])
    }
  }

  @available(iOS 10, *)
  override func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    let userInfo = response.notification.request.content.userInfo
    print("📨 Notification tapped: \(userInfo)")
    
    notificationChannel?.invokeMethod("onNotificationTapped", arguments: userInfo)
    completionHandler()
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  private func setupDeepLinkMethodChannel() {
    deepLinkChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "getInitialLink":
        // Return any initial deep link that launched the app
        result(nil) // We'll handle this through the standard URL handling
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  // Handle custom URL schemes
  override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
    handleDeepLink(url: url)
    // Return true to indicate we handled the URL and prevent iOS from falling back to Safari
    return true
  }
  
  // Handle universal links
  override func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL {
      handleDeepLink(url: url)
    }
    // Return true to indicate we handled the universal link to avoid Safari bounce
    return true
  }
  
  private func handleDeepLink(url: URL) {
    let incoming = url.absoluteString
    let now = Date()
    
    print("🔗 iOS AppDelegate: Deep link received: \(incoming)")
    print("🔗 iOS AppDelegate: URL components:")
    print("   Absolute string: \(incoming)")
    print("   Scheme: \(url.scheme ?? 'nil')")
    print("   Host: \(url.host ?? 'nil')")
    print("   Path: \(url.path)")
    print("   Query: \(url.query ?? 'nil')")
    print("   Fragment: \(url.fragment ?? 'nil')")
    
    if let lastUrl = lastDeepLinkUrl, let lastAt = lastDeepLinkAt {
      if lastUrl == incoming && now.timeIntervalSince(lastAt) < 2.0 {
        print("🔗 iOS AppDelegate: Deep link ignored (native duplicate within window): \(incoming)")
        return
      }
    }
    lastDeepLinkUrl = incoming
    lastDeepLinkAt = now
    
    print("🔗 iOS AppDelegate: Sending deep link to Flutter: \(incoming)")
    deepLinkChannel?.invokeMethod("handleDeepLink", arguments: incoming)
  }

  private func setupInstagramShareMethodChannel() {
    instagramShareChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { result(FlutterError(code: "UNAVAILABLE", message: "Self deallocated", details: nil)); return }
      switch call.method {
      case "shareToStory":
        guard let args = call.arguments as? [String: Any],
              let contentURL = args["contentURL"] as? String else {
          result(FlutterError(code: "BAD_ARGS", message: "contentURL required", details: nil))
          return
        }
        let topColor = args["topColor"] as? String
        let bottomColor = args["bottomColor"] as? String
        let success = self.shareToInstagramStory(contentURL: contentURL, topColor: topColor, bottomColor: bottomColor)
        result(success)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func shareToInstagramStory(contentURL: String, topColor: String?, bottomColor: String?) -> Bool {
    guard let urlScheme = URL(string: "instagram-stories://share"), UIApplication.shared.canOpenURL(urlScheme) else {
      return false
    }
    var pasteboardItems: [String: Any] = [
      "com.instagram.sharedSticker.contentURL": contentURL
    ]
    if let topColor = topColor { pasteboardItems["com.instagram.sharedSticker.backgroundTopColor"] = topColor }
    if let bottomColor = bottomColor { pasteboardItems["com.instagram.sharedSticker.backgroundBottomColor"] = bottomColor }

    UIPasteboard.general.setItems([pasteboardItems], options: [UIPasteboard.OptionsKey.expirationDate: Date().addingTimeInterval(300)])
    UIApplication.shared.open(urlScheme, options: [:], completionHandler: nil)
    return true
  }
}
