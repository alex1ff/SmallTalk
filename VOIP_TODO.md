# VoIP Implementation TODO

## ✅ Completed
- [x] Add VoIP dependencies (callkit, FCM)
- [x] Create VoIPService class
- [x] Integrate in main.dart with background handler
- [x] Configure iOS Info.plist
- [x] Configure Android AndroidManifest.xml
- [x] Push code to develop branch

## 🚧 Next Steps

### High Priority
- [ ] Update Cloud Function `acceptCall` to send VoIP push
- [ ] Create VoIP Certificate in Apple Developer
- [ ] Upload VoIP Certificate to Firebase Cloud Messaging
- [ ] Implement navigation to VideoCallPage
- [ ] Test on real iOS device
- [ ] Test on real Android device

### Medium Priority
- [ ] Implement `_handleCallDecline()` - call Cloud Function
- [ ] Implement `_handleCallEnded()` - call Cloud Function
- [ ] Add error handling for failed calls

### Testing Checklist
- [ ] FCM token saves to Firestore
- [ ] VoIP push received
- [ ] CallKit UI shows
- [ ] Accept button works
- [ ] Decline button works
- [ ] Timeout works (45 sec)
- [ ] Works from closed state
- [ ] Works from background
- [ ] Works over lock screen