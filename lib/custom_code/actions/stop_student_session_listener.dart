// Automatic FlutterFlow imports
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'start_student_session_listener.dart';

Future stopStudentSessionListener() async {
  await studentSessionSub?.cancel();
  studentSessionSub = null;
  studentNavigationHandled = false;
}
