import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:luzhire/core/data/models.dart';
import 'package:luzhire/features/news/data/news_repository.dart';

final _now = DateTime.utc(2026, 10, 21, 6);

NewsItem fakeHeadline(
  int i, {
  String source = 'devto',
  List<String> categories = const ['career-tips'],
  bool featured = false,
}) => NewsItem(
  id: 'h-$i',
  source: source,
  title: 'Headline $i about careers',
  summary: 'Short excerpt for headline $i.',
  url: 'https://dev.to/x/headline-$i',
  publishedAt: _now.subtract(Duration(hours: i)),
  categories: categories,
  isFeatured: featured,
);

NewsItem fakeArticle({
  String slug = 'ace-your-campus-drive',
  bool published = true,
}) => NewsItem(
  id: 'a-$slug',
  source: 'luzhire',
  title: 'How to ace your campus drive',
  summary: 'A checklist for placement season.',
  slug: slug,
  isArticle: true,
  publishedAt: _now.subtract(const Duration(minutes: 30)),
  categories: const ['interviews'],
  isPublished: published,
  authorName: 'Ada Admin',
  bodyMd:
      '## Before the drive\n- Research the company\n- Practise aptitude tests',
);

/// In-memory news_articles with the same filters as the real repository.
class FakeNewsRepository implements NewsRepository {
  FakeNewsRepository([List<NewsItem>? items])
    : items =
          items ??
          [
            fakeArticle(),
            fakeHeadline(1, featured: true, categories: ['hiring-trends']),
            fakeHeadline(2, source: 'remotive', categories: ['remote-work']),
            fakeHeadline(3, categories: ['interviews']),
            fakeHeadline(4),
          ];
  final List<NewsItem> items;
  final saved = <Map<String, Object?>>[];
  final curated = <(String, bool?, bool?)>[];

  List<NewsItem> get _published =>
      items.where((i) => i.isPublished).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  @override
  Future<List<NewsItem>> feed({
    String? topic,
    int offset = 0,
    int limit = 12,
  }) async => _published
      .where(
        (i) => topic == null
            ? true
            : topic == luzhireTopic
            ? i.isArticle
            : i.categories.contains(topic),
      )
      .skip(offset)
      .take(limit)
      .toList();

  @override
  Future<List<NewsItem>> featured({int limit = 4}) async =>
      _published.where((i) => i.isFeatured).take(limit).toList();

  @override
  Future<NewsItem?> article(String slug) async =>
      items.where((i) => i.isArticle && i.slug == slug).firstOrNull;

  @override
  Future<List<NewsItem>> all({required bool articles, int limit = 100}) async =>
      items.where((i) => i.isArticle == articles).toList();

  @override
  Future<void> saveArticle({
    String? id,
    required String title,
    required String summary,
    required String bodyMd,
    required List<String> categories,
    required bool featured,
    required bool publish,
  }) async {
    saved.add({
      'id': id,
      'title': title,
      'body': bodyMd,
      'categories': categories,
      'featured': featured,
      'publish': publish,
    });
    items.insert(
      0,
      NewsItem(
        id: id ?? 'a-new-${saved.length}',
        source: 'luzhire',
        title: title,
        summary: summary,
        slug: 'new-${saved.length}',
        isArticle: true,
        publishedAt: _now,
        categories: categories,
        isFeatured: featured,
        isPublished: publish,
        bodyMd: bodyMd,
      ),
    );
  }

  @override
  Future<void> curate(String id, {bool? featured, bool? published}) async =>
      curated.add((id, featured, published));

  @override
  Future<void> delete(String id) async => items.removeWhere((i) => i.id == id);
}

List<Override> newsOverrides([FakeNewsRepository? repo]) => [
  newsRepositoryProvider.overrideWithValue(repo ?? FakeNewsRepository()),
];
