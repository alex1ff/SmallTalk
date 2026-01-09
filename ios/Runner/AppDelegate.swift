import UIKit
import Flutter
import PushKit
import flutter_callkit_incoming

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let mainQueue = DispatchQueue.main
    let voipRegistry: PKPushRegistry = PKPushRegistry(queue: mainQueue)
    voipRegistry.delegate = self
    voipRegistry.desiredPushTypes = [PKPushType.voIP]

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didUpdate credentials: PKPushCredentials,
    for type: PKPushType
  ) {
    guard type == .voIP else { return }
    let deviceToken = credentials.token.map { String(format: "%02x", $0) }.joined()
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP(deviceToken)
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didInvalidatePushTokenFor type: PKPushType
  ) {
    guard type == .voIP else { return }
    SwiftFlutterCallkitIncomingPlugin.sharedInstance?.setDevicePushTokenVoIP("")
  }

  func pushRegistry(
    _ registry: PKPushRegistry,
    didReceiveIncomingPushWith payload: PKPushPayload,
    for type: PKPushType,
    completion: @escaping () -> Void
  ) {
    guard type == .voIP else {
      completion()
      return
    }

    var didComplete = false
    func finish() {
      if didComplete { return }
      didComplete = true
      completion()
    }

    let payloadDict = payload.dictionaryPayload.reduce(into: [String: Any]()) { result, entry in
      if let key = entry.key as? String {
        result[key] = entry.value
      }
    }

    let sessionId = (payloadDict["sessionId"] as? String) ??
      (payloadDict["id"] as? String)
    if let sessionId {
      payloadDict["sessionId"] = sessionId
    }

    let rawCallKitId =
      (payloadDict["callKitId"] as? String) ??
      sessionId ??
      UUID().uuidString
    let callKitId = UUID(uuidString: rawCallKitId) != nil
      ? rawCallKitId
      : UUID().uuidString
    let nameCaller = (payloadDict["callerName"] as? String) ??
      (payloadDict["nameCaller"] as? String) ??
      "Incoming call"
    let handle = (payloadDict["callerId"] as? String) ??
      (payloadDict["handle"] as? String) ??
      ""
    let isVideo = payloadDict["isVideo"] as? Bool ?? true

    let data = flutter_callkit_incoming.Data(
      id: callKitId,
      nameCaller: nameCaller,
      handle: handle,
      type: isVideo ? 1 : 0
    )
    data.extra = NSDictionary(dictionary: payloadDict)

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      finish()
    }

    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      plugin.showCallkitIncoming(data, fromPushKit: true) {
        finish()
      }
    } else {
      finish()
    }
  }
}
