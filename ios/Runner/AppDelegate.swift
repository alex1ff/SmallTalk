import UIKit
import Flutter
import PushKit
import CryptoKit
import flutter_callkit_incoming

private let incomingCallTimeoutMilliseconds = 45000

private let incomingCallExtraKeys: Set<String> = [
  "type",
  "sessionId",
  "callerName",
  "callerId",
  "callerPhoto",
  "studentName",
  "studentId",
  "studentPhoto",
  "language",
  "scenario",
  "recipientId",
  "requesterId",
  "responderId",
  "requesterRole",
  "responderRole",
  "navRole",
  "acceptMode",
  "callKitId",
  "notificationId",
  "searchRequestId",
  "expiresAt",
  "roomUrl",
  "meetingToken",
  "roomName",
  "tokenStrategy"
]

private func incomingCallExtraData(from payload: [String: Any]) -> [String: Any] {
  var extra: [String: Any] = [:]
  for key in incomingCallExtraKeys {
    if let value = payload[key], !(value is NSNull) {
      extra[key] = value
    }
  }
  return extra
}

private func deterministicCallKitId(for rawValue: String?) -> String {
  let trimmed = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  if trimmed.isEmpty {
    return UUID().uuidString.lowercased()
  }
  if let existingUuid = UUID(uuidString: trimmed) {
    return existingUuid.uuidString.lowercased()
  }

  let digest = Insecure.MD5.hash(data: Data("smalltalk-call:\(trimmed)".utf8))
  var bytes = Array(digest)
  bytes[6] = (bytes[6] & 0x0f) | 0x30
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  let hex = bytes.map { String(format: "%02x", $0) }.joined()

  return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
}

@main
@objc class AppDelegate: FlutterAppDelegate, PKPushRegistryDelegate {
  private var voipRegistry: PKPushRegistry?

  private func applyKeyboardBackdrop() {
    let backdropColor = UIColor(
      red: 250.0 / 255.0,
      green: 250.0 / 255.0,
      blue: 250.0 / 255.0,
      alpha: 1.0
    )
    window?.backgroundColor = backdropColor
    window?.rootViewController?.view.backgroundColor = backdropColor
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    voipRegistry = PKPushRegistry(queue: DispatchQueue.main)
    voipRegistry?.delegate = self
    voipRegistry?.desiredPushTypes = [PKPushType.voIP]

    let didFinishLaunching = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    applyKeyboardBackdrop()
    DispatchQueue.main.async { [weak self] in
      self?.applyKeyboardBackdrop()
    }
    return didFinishLaunching
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    applyKeyboardBackdrop()
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

    var payloadDict = payload.dictionaryPayload.reduce(into: [String: Any]()) { result, entry in
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
      sessionId
    let callKitId = deterministicCallKitId(for: rawCallKitId)
    payloadDict["callKitId"] = callKitId
    if payloadDict["type"] as? String == "call_cancelled" {
      let cancelData = flutter_callkit_incoming.Data(
        id: callKitId,
        nameCaller: "",
        handle: "",
        type: 1
      )
      SwiftFlutterCallkitIncomingPlugin.sharedInstance?.endCall(cancelData)
      finish()
      return
    }

    let nameCaller = (payloadDict["callerName"] as? String) ??
      (payloadDict["nameCaller"] as? String) ??
      "Incoming call"
    let handle = (payloadDict["callerId"] as? String) ??
      (payloadDict["handle"] as? String) ??
      ""
    payloadDict["callerName"] = nameCaller
    payloadDict["callerId"] = handle
    let isVideo = payloadDict["isVideo"] as? Bool ?? true

    let data = flutter_callkit_incoming.Data(
      id: callKitId,
      nameCaller: nameCaller,
      handle: handle,
      type: isVideo ? 1 : 0
    )
    let extraDict = incomingCallExtraData(from: payloadDict)
    data.duration = incomingCallTimeoutMilliseconds
    data.extra = NSDictionary(dictionary: extraDict)

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
