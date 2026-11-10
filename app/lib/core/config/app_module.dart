import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../data/enums.dart';
import '../platform/page_meta.dart';

/// Which part of LuzHire this page serves. Production serves everything
/// ([AppModule.all]); the offline demo serves one module per port, each
/// for one role (docs/OFFLINE_DEMO.md).
enum AppModule {
  all,
  candidate,
  recruiter,
  admin;

  String get label => switch (this) {
    all => 'LuzHire',
    candidate => 'Candidate',
    recruiter => 'Recruiter',
    admin => 'Admin',
  };

  /// The one role this module signs in; null = every role.
  AppRole? get role => switch (this) {
    all => null,
    candidate => AppRole.candidate,
    recruiter => AppRole.employer,
    admin => AppRole.admin,
  };

  static AppModule forRole(AppRole role) => switch (role) {
    AppRole.candidate => candidate,
    AppRole.employer => recruiter,
    AppRole.admin => admin,
  };
}

/// The module and where the other modules are served.
@immutable
class ModuleConfig {
  const ModuleConfig({this.module = AppModule.all, this.links = const {}});

  final AppModule module;
  final Map<AppModule, String> links;

  bool allows(AppRole role) => module.role == null || module.role == role;

  /// Reads `<meta name="luz-module" content='{"module": "recruiter",
  /// "links": {"candidate": "http://localhost:8081", ...}}'>`.
  factory ModuleConfig.fromPage() => ModuleConfig.parse(pageMeta('luz-module'));

  factory ModuleConfig.parse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const ModuleConfig();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      AppModule? named(Object? v) =>
          AppModule.values.where((m) => m.name == v).firstOrNull;
      final links = <AppModule, String>{};
      final rawLinks = json['links'];
      if (rawLinks is Map) {
        rawLinks.forEach((k, v) {
          final m = named(k);
          if (m != null && v is String) links[m] = v;
        });
      }
      return ModuleConfig(
        module: named(json['module']) ?? AppModule.all,
        links: links,
      );
    } catch (_) {
      return const ModuleConfig();
    }
  }
}
