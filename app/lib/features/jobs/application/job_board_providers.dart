import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_state.dart';
import '../../companies/data/companies_repository.dart';
import '../data/jobs_repository.dart';

// ---------------------------------------------------------------- search

@immutable
class JobSearchState {
  const JobSearchState({
    this.jobs = const [],
    this.loading = false,
    this.hasMore = true,
    this.error,
  });

  final List<Job> jobs;
  final bool loading;
  final bool hasMore;
  final AppFailure? error;

  /// First page still loading.
  bool get isInitialLoad => loading && jobs.isEmpty;
}

/// Keyset-paginated results for one [JobSearchQuery] (newest first).
class JobSearchController extends Notifier<JobSearchState> {
  JobSearchController(this.query);
  final JobSearchQuery query;
  bool _inFlight = false;

  @override
  JobSearchState build() {
    Future.microtask(loadMore);
    return const JobSearchState(loading: true);
  }

  Future<void> loadMore() async {
    if (_inFlight || !state.hasMore) return;
    _inFlight = true;
    state = JobSearchState(jobs: state.jobs, loading: true);
    try {
      final page = await ref
          .read(jobsRepositoryProvider)
          .search(query, after: state.jobs.isEmpty ? null : state.jobs.last);
      if (!ref.mounted) return;
      ref.read(jobPreviewsProvider).addAll(page);
      state = JobSearchState(
        jobs: [...state.jobs, ...page],
        hasMore: page.length >= query.pageSize,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = JobSearchState(
        jobs: state.jobs,
        hasMore: state.hasMore,
        error: mapDbError(e),
      );
    } finally {
      _inFlight = false;
    }
  }

  /// After an error: try the failed page again.
  Future<void> retry() => loadMore();
}

final jobSearchProvider = NotifierProvider.autoDispose
    .family<JobSearchController, JobSearchState, JobSearchQuery>(
      JobSearchController.new,
    );

/// All skills (for the filter panel), alphabetical.
final skillsProvider =
    FutureProvider.autoDispose<List<({String slug, String name})>>(
      (ref) => ref.watch(jobsRepositoryProvider).skills(),
    );

// ---------------------------------------------------------------- detail

/// Card fields of jobs seen in search results, by slug. Opening one shows
/// them at once while [jobBySlugProvider] loads the description.
class JobPreviews {
  static const capacity = 500;
  final _bySlug = <String, Job>{};

  Job? operator [](String slug) => _bySlug[slug];

  void addAll(Iterable<Job> jobs) {
    for (final job in jobs) {
      _bySlug
        ..remove(job.slug)
        ..[job.slug] = job;
    }
    while (_bySlug.length > capacity) {
      _bySlug.remove(_bySlug.keys.first);
    }
  }
}

final jobPreviewsProvider = Provider<JobPreviews>((ref) => JobPreviews());

final jobBySlugProvider = FutureProvider.autoDispose.family<Job?, String>(
  (ref, slug) => ref.watch(jobsRepositoryProvider).bySlug(slug),
);

final jobSkillsProvider = FutureProvider.autoDispose
    .family<List<String>, String>(
      (ref, jobId) => ref.watch(jobsRepositoryProvider).jobSkills(jobId),
    );

final companyByIdProvider = FutureProvider.autoDispose.family<Company?, String>(
  (ref, id) => ref.watch(companiesRepositoryProvider).byId(id),
);

final companyBySlugProvider = FutureProvider.autoDispose
    .family<Company?, String>(
      (ref, slug) => ref.watch(companiesRepositoryProvider).bySlug(slug),
    );

// ---------------------------------------------------------------- companies

@immutable
class CompanyListState {
  const CompanyListState({
    this.companies = const [],
    this.loading = false,
    this.hasMore = true,
    this.error,
  });
  final List<Company> companies;
  final bool loading;
  final bool hasMore;
  final AppFailure? error;
  bool get isInitialLoad => loading && companies.isEmpty;
}

class CompanyListController extends Notifier<CompanyListState> {
  CompanyListController(this.query);
  final String query;
  static const pageSize = 24;
  bool _inFlight = false;

  @override
  CompanyListState build() {
    Future.microtask(loadMore);
    return const CompanyListState(loading: true);
  }

  Future<void> loadMore() async {
    if (_inFlight || !state.hasMore) return;
    _inFlight = true;
    state = CompanyListState(companies: state.companies, loading: true);
    try {
      final page = await ref
          .read(companiesRepositoryProvider)
          .list(query: query, offset: state.companies.length, limit: pageSize);
      if (!ref.mounted) return;
      state = CompanyListState(
        companies: [...state.companies, ...page],
        hasMore: page.length >= pageSize,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = CompanyListState(
        companies: state.companies,
        hasMore: state.hasMore,
        error: mapDbError(e),
      );
    } finally {
      _inFlight = false;
    }
  }
}

final companyListProvider = NotifierProvider.autoDispose
    .family<CompanyListController, CompanyListState, String>(
      CompanyListController.new,
    );

// ---------------------------------------------------------------- saved jobs

/// The signed-in user's id, or null for visitors.
final currentUidProvider = Provider<String?>((ref) {
  final auth = ref.watch(authControllerProvider);
  return auth is SignedIn ? auth.user.uid : null;
});

/// Live saved-job ids (synced across devices through Realtime).
final savedJobIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const <String>{});
  return ref.watch(savedJobsRepositoryProvider).watchIds(uid);
});

/// Saved ids including taps that Realtime hasn't echoed back yet.
class SavedJobsController extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    // A fresh server snapshot supersedes pending optimistic changes.
    ref.listen(savedJobIdsProvider, (_, _) => state = const {});
    ref.watch(currentUidProvider);
    return const {};
  }

  bool isSaved(String jobId) =>
      state[jobId] ??
      (ref.read(savedJobIdsProvider).value ?? const {}).contains(jobId);

  /// Saves or removes [jobId]; throws [AppFailure] on failure (and undoes the
  /// optimistic change). Requires a signed-in user.
  Future<void> toggle(String jobId) async {
    final uid = ref.read(currentUidProvider);
    if (uid == null) {
      throw const AppFailure('Sign in to save jobs.', code: 'signed_out');
    }
    final save = !isSaved(jobId);
    state = {...state, jobId: save};
    try {
      final repo = ref.read(savedJobsRepositoryProvider);
      save ? await repo.save(uid, jobId) : await repo.remove(uid, jobId);
    } catch (e) {
      state = {...state}..remove(jobId);
      throw mapDbError(e);
    }
  }
}

final savedJobsControllerProvider =
    NotifierProvider<SavedJobsController, Map<String, bool>>(
      SavedJobsController.new,
    );

/// The saved jobs themselves, for the /me/saved page.
final savedJobsProvider = FutureProvider.autoDispose<List<Job>>((ref) async {
  final ids = await ref.watch(savedJobIdsProvider.future);
  return ref.watch(jobsRepositoryProvider).byIds(ids);
});

/// Whether [jobId] is saved, rebuilding on server and optimistic changes.
final isJobSavedProvider = Provider.autoDispose.family<bool, String>((ref, id) {
  final pending = ref.watch(savedJobsControllerProvider);
  final ids = ref.watch(savedJobIdsProvider).value ?? const <String>{};
  return pending[id] ?? ids.contains(id);
});

// ---------------------------------------------------------------- new jobs

/// How often an open page checks for newly arrived jobs. A small count query
/// once a minute instead of Realtime on `jobs`, which would push every
/// imported row (about 1,800 a day, in bursts) to every open browser.
const newJobsPollInterval = Duration(minutes: 1);

/// Jobs that arrived since the page opened (or since "Show" was tapped).
class NewJobsController extends Notifier<int> {
  late DateTime _since;
  Timer? _timer;

  @override
  int build() {
    _since = DateTime.now();
    _timer = Timer.periodic(newJobsPollInterval, (_) => _check());
    ref.onDispose(() => _timer?.cancel());
    return 0;
  }

  Future<void> _check() async {
    try {
      final n = await ref.read(jobsRepositoryProvider).countNewSince(_since);
      if (ref.mounted) state = n;
    } catch (_) {
      // Offline or not configured: try again next minute.
    }
  }

  /// The new jobs are being shown: count from now on.
  void reset() {
    _since = DateTime.now();
    state = 0;
  }
}

final newJobsProvider = NotifierProvider.autoDispose<NewJobsController, int>(
  NewJobsController.new,
);
