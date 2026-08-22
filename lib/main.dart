import 'package:flutter/material.dart';

import 'app.dart';
import 'l10n/strings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initLanguage();
  runApp(const TidyPikaApp());
}
