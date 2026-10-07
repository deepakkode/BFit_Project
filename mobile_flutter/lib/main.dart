import 'package:flutter/material.dart';

import 'app.dart';
import 'core/app_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(BFitApp(controller: AppController()));
}
