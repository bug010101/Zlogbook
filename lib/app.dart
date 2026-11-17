import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:zlogbook/core/app_info.dart';
import 'package:zlogbook/core/theme.dart';
import 'package:zlogbook/pages/home_page.dart';
import 'package:zlogbook/state/app_scope.dart';
import 'package:zlogbook/state/app_state.dart';

class ZlogbookApp extends StatelessWidget {
  const ZlogbookApp({super.key, required this.state, this.fatalError});

  final AppState state;
  final String? fatalError;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: MaterialApp(
        title: AppInfo.name,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        locale: const Locale('zh', 'CN'),
        supportedLocales: const <Locale>[
          Locale('zh', 'CN'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: fatalError == null
            ? const HomePage()
            : _StartupErrorPage(message: fatalError!, state: state),
      ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.message, required this.state});

  final String message;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.error_outline, size: 40, color: kInkSoft),
              const SizedBox(height: 14),
              const Text(
                '数据打不开',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: kInkSoft),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => state.bootstrap(),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
