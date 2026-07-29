import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

typedef AppInitializer = Future<void> Function();

class AppBootstrapGate extends StatefulWidget {
  const AppBootstrapGate({
    required this.initialize,
    required this.child,
    super.key,
  });

  final AppInitializer initialize;
  final Widget child;

  @override
  State<AppBootstrapGate> createState() => _AppBootstrapGateState();
}

class _AppBootstrapGateState extends State<AppBootstrapGate> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('[bootstrap] initialization failed: $error');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  void _retry() {
    setState(() {
      _initialization = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _BootstrapSurface(
            child: Semantics(
              label: '앱을 준비하는 중',
              child: const CircularProgressIndicator(),
            ),
          );
        }
        if (snapshot.hasError) {
          return _BootstrapSurface(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '앱을 시작하지 못했어요',
                  style: AppTheme.light.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '잠시 후 다시 시도해 주세요',
                  style: AppTheme.light.textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: _retry, child: const Text('다시 시도')),
              ],
            ),
          );
        }
        return widget.child;
      },
    );
  }
}

class _BootstrapSurface extends StatelessWidget {
  const _BootstrapSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(padding: const EdgeInsets.all(24), child: child),
          ),
        ),
      ),
    );
  }
}
