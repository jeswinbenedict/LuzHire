import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/models.dart';
import '../../../core/data/supabase_providers.dart';
import '../../auth/application/auth_controller.dart';
import '../../jobs/data/jobs_repository.dart' show notConfigured;

/// News topics; slugs match `categories` set by the import (api/_lib/news).
typedef NewsTopic = ({String slug, String label, IconData icon});

const newsTopics = <NewsTopic>[
  (slug: 'career-tips', label: 'Career tips', icon: Icons.lightbulb_outline),
  (slug: 'interviews', label: 'Interviews & CVs', icon: Icons.forum_outlined),
  (slug: 'remote-work', label: 'Remote work', icon: Icons.home_work_outlined),
  (slug: 'skills', label: 'Skills & learning', icon: Icons.school_outlined),
  (slug: 'hiring-trends', label: 'Hiring trends', icon: Icons.trending_up),
];

/// The filter for LuzHire's own articles (not a category).
const luzhireTopic = 'luzhire';

NewsTopic? newsTopic(String slug) =>
    newsTopics.where((t) => t.slug == slug).firstOrNull;

/// Publisher names for imported headlines.
String newsSourceLabel(String source) => switch (source) {
  'luzhire' => 'LuzHire',
  'remotive' => 'Remotive',
  'devto' => 'DEV Community',
  'freecodecamp' => 'freeCodeCamp',
  _ => source,
};

/// Everything but the article body, for cards and lists.
const _cardColumns =
    'id, kind, source, url, slug, title, summary, image_url, published_at, '
    'categories, is_featured, status, author_name';

class NewsRepository {
  NewsRepository(this._db);
  final SupabaseClient _db;

  /// Published items, newest first. [topic] is a category slug or
  /// [luzhireTopic].
  Future<List<NewsItem>> feed({
    String? topic,
    int offset = 0,
    int limit = 12,
  }) => guardDb(() async {
    var q = _db
        .from('news_articles')
        .select(_cardColumns)
        .eq('status', 'published');
    if (topic == luzhireTopic) {
      q = q.eq('kind', 'article');
    } else if (topic != null) {
      q = q.contains('categories', [topic]);
    }
    final rows = await q
        .order('published_at', ascending: false)
        .order('id')
        .range(offset, offset + limit - 1);
    return [for (final r in rows) NewsItem.fromJson(r)];
  });

  /// Featured items for the top of /news, newest first.
  Future<List<NewsItem>> featured({int limit = 4}) => guardDb(() async {
    final rows = await _db
        .from('news_articles')
        .select(_cardColumns)
        .eq('status', 'published')
        .eq('is_featured', true)
        .order('published_at', ascending: false)
        .limit(limit);
    return [for (final r in rows) NewsItem.fromJson(r)];
  });

  /// A LuzHire article with its body (drafts only for admins, through RLS).
  Future<NewsItem?> article(String slug) => guardDb(() async {
    final row = await _db
        .from('news_articles')
        .select('$_cardColumns, body_md')
        .eq('kind', 'article')
        .eq('slug', slug)
        .maybeSingle();
    return row == null ? null : NewsItem.fromJson(row);
  });

  // ---------------------------------------------------------- admin

  /// Everything, drafts and hidden headlines included (admins only).
  Future<List<NewsItem>> all({required bool articles, int limit = 100}) =>
      guardDb(() async {
        final rows = await _db
            .from('news_articles')
            .select('$_cardColumns, body_md')
            .eq('kind', articles ? 'article' : 'headline')
            .order('published_at', ascending: false)
            .limit(limit);
        return [for (final r in rows) NewsItem.fromJson(r)];
      });

  Future<void> saveArticle({
    String? id,
    required String title,
    required String summary,
    required String bodyMd,
    required List<String> categories,
    required bool featured,
    required bool publish,
  }) => guardDb(() async {
    final row = {
      'title': title.trim(),
      'summary': summary.trim().isEmpty ? null : summary.trim(),
      'body_md': bodyMd.trim(),
      'categories': categories,
      'is_featured': featured,
      'status': publish ? 'published' : 'draft',
    };
    if (id == null) {
      await _db.from('news_articles').insert({
        ...row,
        'kind': 'article',
        'source': 'luzhire',
      });
    } else {
      await _db.from('news_articles').update(row).eq('id', id);
    }
  });

  /// Features or hides any item (a hidden headline is not imported again).
  Future<void> curate(String id, {bool? featured, bool? published}) => guardDb(
    () => _db
        .from('news_articles')
        .update({
          'is_featured': ?featured,
          if (published != null) 'status': published ? 'published' : 'draft',
        })
        .eq('id', id),
  );

  Future<void> delete(String id) =>
      guardDb(() => _db.from('news_articles').delete().eq('id', id));
}

final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  if (!ref.watch(appConfigProvider).isSupabaseConfigured) throw notConfigured;
  return NewsRepository(ref.watch(supabaseClientProvider));
});
