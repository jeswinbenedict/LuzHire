import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase + Supabase initialisation is added in Phase 2 (bootstrap.dart).
  runApp(const ProviderScope(child: LuzHireApp()));
}
