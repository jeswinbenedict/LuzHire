import 'dart:async';

import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/features/notifications/data/push_service.dart';

/// A browser/phone whose permission prompt answers with [answer].
class FakePushService implements PushService {
  FakePushService({
    this.isSupported = true,
    this.current = PushPermission.notDetermined,
    this.answer = PushPermission.granted,
    this.deviceToken = 'fake-device-token-0000000001',
  });

  bool isSupported;
  PushPermission current;
  PushPermission answer;
  String? deviceToken;
  int prompts = 0;
  final refresh = StreamController<String>.broadcast();
  final opened = StreamController<String>.broadcast();

  @override
  Future<bool> supported() async => isSupported;

  @override
  Future<PushPermission> permission() async => current;

  @override
  Future<PushPermission> requestPermission() async {
    prompts++;
    return current = answer;
  }

  @override
  Future<String?> token() async => deviceToken;

  @override
  PushPlatform get platform => PushPlatform.web;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<String> get onOpenedLink => opened.stream;

  @override
  Future<String?> initialLink() async => null;
}
