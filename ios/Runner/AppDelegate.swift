import Flutter
import UIKit

private func zolozUnhandledExceptionHandler(_ exception: NSException) {
  let symbols = exception.callStackSymbols.joined(separator: " | ")
  NSLog(
    "[Repro][NSException] name=%@ reason=%@ stack=%@",
    exception.name.rawValue,
    exception.reason ?? "nil",
    symbols
  )
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    NSSetUncaughtExceptionHandler(zolozUnhandledExceptionHandler)
    registerLifecycleDiagnostics()

    if let launchOptions {
      NSLog("[Repro][AppLaunch] options=%@", launchOptions.description)
    } else {
      NSLog("[Repro][AppLaunch] options=nil")
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    NSLog("[Repro][FlutterEngine] didInitializeImplicitFlutterEngine")
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func registerLifecycleDiagnostics() {
    let center = NotificationCenter.default
    center.addObserver(
      self,
      selector: #selector(handleDidBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    center.addObserver(
      self,
      selector: #selector(handleWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification,
      object: nil
    )
  }

  @objc private func handleDidBecomeActive() {
    NSLog("[Repro][Lifecycle] didBecomeActive")
  }

  @objc private func handleWillResignActive() {
    NSLog("[Repro][Lifecycle] willResignActive")
  }

  @objc private func handleDidEnterBackground() {
    NSLog("[Repro][Lifecycle] didEnterBackground")
  }

  @objc private func handleWillEnterForeground() {
    NSLog("[Repro][Lifecycle] willEnterForeground")
  }
}
