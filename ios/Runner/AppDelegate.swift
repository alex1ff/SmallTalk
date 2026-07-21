import UIKit
import Flutter
import PushKit
import CryptoKit
import flutter_callkit_incoming

private let incomingCallTimeoutMilliseconds = 45000
private let cancelledCallKitTombstonesKey = "smalltalk.cancelledCallKitTombstones"
private let flutterServerEndedCallKitTombstonesKey =
  "flutter.smalltalk.serverEndedCallKitTombstones"
private let cancelledCallKitTombstoneTTL: TimeInterval = 10 * 60

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
  "tokenStrategy",
  "matchProtocolVersion",
  "confirmationVersion",
  "pairAttemptId",
  "surface",
  "delivery",
  "deliveryFailureKind"
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

private func activeCancelledCallKitTombstones(now: Date) -> [String: Double] {
  let defaults = UserDefaults.standard
  let stored = defaults.dictionary(forKey: cancelledCallKitTombstonesKey) ?? [:]
  var merged = stored
  if
    let flutterJSON = defaults.string(forKey: flutterServerEndedCallKitTombstonesKey),
    let data = flutterJSON.data(using: .utf8),
    let flutterStored = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
  {
    for (callKitId, timestamp) in flutterStored {
      merged[callKitId] = timestamp
    }
  }
  let nowSeconds = now.timeIntervalSince1970
  var active: [String: Double] = [:]
  for (callKitId, rawTimestamp) in merged {
    guard let timestamp = (rawTimestamp as? NSNumber)?.doubleValue else { continue }
    let age = nowSeconds - timestamp
    if age >= 0 && age <= cancelledCallKitTombstoneTTL {
      active[callKitId] = timestamp
    }
  }
  defaults.set(active, forKey: cancelledCallKitTombstonesKey)
  if
    let data = try? JSONSerialization.data(withJSONObject: active),
    let json = String(data: data, encoding: .utf8)
  {
    defaults.set(json, forKey: flutterServerEndedCallKitTombstonesKey)
  }
  return active
}

private func rememberCancelledCallKitId(_ callKitId: String, now: Date) {
  var tombstones = activeCancelledCallKitTombstones(now: now)
  tombstones[callKitId] = now.timeIntervalSince1970
  UserDefaults.standard.set(tombstones, forKey: cancelledCallKitTombstonesKey)
  if
    let data = try? JSONSerialization.data(withJSONObject: tombstones),
    let json = String(data: data, encoding: .utf8)
  {
    UserDefaults.standard.set(
      json,
      forKey: flutterServerEndedCallKitTombstonesKey
    )
  }
}

private func wasCallKitIdRecentlyCancelled(_ callKitId: String, now: Date) -> Bool {
  return activeCancelledCallKitTombstones(now: now)[callKitId] != nil
}

private func incomingCallExpiryDate(from payload: [String: Any]) -> Date? {
  if let number = payload["expiresAt"] as? NSNumber {
    let rawValue = number.doubleValue
    let seconds = rawValue > 10_000_000_000 ? rawValue / 1000 : rawValue
    return Date(timeIntervalSince1970: seconds)
  }
  guard let rawValue = payload["expiresAt"] as? String else { return nil }
  let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else { return nil }
  if let numericValue = Double(trimmed) {
    let seconds = numericValue > 10_000_000_000 ? numericValue / 1000 : numericValue
    return Date(timeIntervalSince1970: seconds)
  }
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  if let date = formatter.date(from: trimmed) {
    return date
  }
  formatter.formatOptions = [.withInternetDateTime]
  return formatter.date(from: trimmed)
}

private func incomingCallDurationMilliseconds(
  from payload: [String: Any],
  now: Date
) -> Int {
  guard let expiryDate = incomingCallExpiryDate(from: payload) else {
    return incomingCallTimeoutMilliseconds
  }
  let remainingMilliseconds = Int(expiryDate.timeIntervalSince(now) * 1000)
  return max(1, min(incomingCallTimeoutMilliseconds, remainingMilliseconds))
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
      let now = Date()
      rememberCancelledCallKitId(callKitId, now: now)
      let cancelData = flutter_callkit_incoming.Data(
        id: callKitId,
        nameCaller: "Incoming call",
        handle: "",
        type: 1
      )
      cancelData.duration = 1
      cancelData.isShowMissedCallNotification = false
      cancelData.extra = NSDictionary(
        dictionary: incomingCallExtraData(from: payloadDict)
      )
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
        finish()
      }
      if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
        // Every PushKit VoIP payload is reported to CallKit. A cancellation is
        // immediately closed as remote-ended using its exact UUID.
        plugin.showCallkitIncoming(cancelData, fromPushKit: true) {
          plugin.saveEndCall(callKitId, 2)
          finish()
        }
      } else {
        finish()
      }
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
    let now = Date()
    data.duration = incomingCallDurationMilliseconds(from: payloadDict, now: now)
    data.extra = NSDictionary(dictionary: extraDict)
    let shouldEndAfterReporting =
      wasCallKitIdRecentlyCancelled(callKitId, now: now) ||
      (incomingCallExpiryDate(from: payloadDict).map { $0 <= now } ?? false)
    if shouldEndAfterReporting {
      data.isShowMissedCallNotification = false
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      finish()
    }

    if let plugin = SwiftFlutterCallkitIncomingPlugin.sharedInstance {
      if shouldEndAfterReporting {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
          plugin.saveEndCall(callKitId, 2)
        }
      }
      plugin.showCallkitIncoming(data, fromPushKit: true) {
        if shouldEndAfterReporting {
          plugin.saveEndCall(callKitId, 2)
        }
        finish()
      }
    } else {
      finish()
    }
  }
}
