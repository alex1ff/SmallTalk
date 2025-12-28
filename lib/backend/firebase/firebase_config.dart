import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

Future initFirebase() async {
  if (kIsWeb) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
            apiKey: "AIzaSyBRCxuTmxzNF973BXtuR_JT_MraioaHH34",
            authDomain: "smalltalk-2109b.firebaseapp.com",
            projectId: "smalltalk-2109b",
            storageBucket: "smalltalk-2109b.firebasestorage.app",
            messagingSenderId: "1024626146715",
            appId: "1:1024626146715:web:63189c0ffd3746bc6bf53e",
            measurementId: "G-JEB0NK4P5E"));
  } else {
    await Firebase.initializeApp();
  }
}
