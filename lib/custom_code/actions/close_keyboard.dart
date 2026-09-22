// Automatic FlutterFlow imports
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Set your action name, define your arguments and return parameter, and then
/// add the boilerplate code using the green buton on the right!
Future closeKeyboard() async {
  FocusManager.instance.primaryFocus?.unfocus();
}
