import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../data/news_repository.dart';

@immutable
class NewsFeedState {
  const NewsFeedState({
    this.items = const [],
    this.loading = false,
    this.hasMore = true,
    this.error,
  });
  final List<NewsItem> items;
  final bool loading;
  final bool hasMore;
  final AppFailure? error;
  bool get isInitialLoad => loading && items.isEmpty;
}

/// Published news for one topic (null: everything), newest first.
class NewsFeedController extends Notifier<NewsFeedState> {
  NewsFeedController(this.topic);
  final String? topic;
  static const pageSize = 12;
  bool _inFlight = false;

  @override
  NewsFeedState build() {
    Future.microtask(loadMore);
    return const NewsFeedState(loading: true);
  }

  Future<void> loadMore() async {
    if (_inFlight || !state.hasMore) return;
    _inFlight = true;
    state = NewsFeedState(items: state.items, loading: true);
    try {
      final page = await ref
          .read(newsRepositoryProvider)
          .feed(topic: topic, offset: state.items.length, limit: pageSize);
      if (!ref.mounted) return;
      state = NewsFeedState(
        items: [...state.items, ...page],
        hasMore: page.length >= pageSize,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = NewsFeedState(
        items: state.items,
        hasMore: state.hasMore,
        error: mapDbError(e),
      );
    } finally {
      _inFlight = false;
    }
  }
}

final newsFeedProvider = NotifierProvider.autoDispose
    .family<NewsFeedController, NewsFeedState, String?>(NewsFeedController.new);

final featuredNewsProvider = FutureProvider.autoDispose<List<NewsItem>>(
  (ref) => ref.watch(newsRepositoryProvider).featured(),
);

final newsArticleProvider = FutureProvider.autoDispose
    .family<NewsItem?, String>(
      (ref, slug) => ref.watch(newsRepositoryProvider).article(slug),
    );

/// Admin lists: articles (true) or imported headlines (false).
final adminNewsProvider = FutureProvider.autoDispose
    .family<List<NewsItem>, bool>(
      (ref, articles) =>
          ref.watch(newsRepositoryProvider).all(articles: articles),
    );

/// Admin writes; each refreshes the lists that show the change.
class NewsActions {
  NewsActions(this._ref);
  final Ref _ref;
  NewsRepository get _repo => _ref.read(newsRepositoryProvider);

  void _refresh() {
    _ref
      ..invalidate(adminNewsProvider)
      ..invalidate(featuredNewsProvider)
      ..invalidate(newsFeedProvider);
  }

  Future<void> saveArticle({
    String? id,
    required String title,
    required String summary,
    required String bodyMd,
    required List<String> categories,
    required bool featured,
    required bool publish,
  }) async {
    await _repo.saveArticle(
      id: id,
      title: title,
      summary: summary,
      bodyMd: bodyMd,
      categories: categories,
      featured: featured,
      publish: publish,
    );
    _refresh();
  }

  Future<void> curate(String id, {bool? featured, bool? published}) async {
    await _repo.curate(id, featured: featured, published: published);
    _refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _refresh();
  }
}

final newsActionsProvider = Provider<NewsActions>(NewsActions.new);
