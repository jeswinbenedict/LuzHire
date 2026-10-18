import 'package:go_router/go_router.dart';

import '../../features/design_gallery/gallery_page.dart';

/// Routes grow per feature (docs/ARCHITECTURE.md §10). Role guards arrive in Phase 2.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const GalleryPage()),
  ],
);
