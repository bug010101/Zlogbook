import 'package:flutter/material.dart';
import 'package:zlogbook/app.dart';
import 'package:zlogbook/data/db/app_database.dart';
import 'package:zlogbook/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppDatabase.initFactory();

  final AppState state = AppState();
  await state.bootstrap();

  runApp(ZlogbookApp(state: state, fatalError: state.error));
}
