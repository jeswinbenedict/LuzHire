import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/data/failures.dart';
import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/layout/content.dart';
import '../../../core/router/links.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../jobs/presentation/job_search_page.dart' show JobBoardError;
import '../../jobs/presentation/job_widgets.dart'
    show LoadMoreFooter, SimpleMarkdown;
import '../application/news_providers.dart';
import '../data/news_repository.dart';

/// Opens an item: LuzHire articles in the app, headlines on their
/// publisher's site.
void openNews(BuildContext context, NewsItem item) {
  if (item.isArticle && item.slug != null) {
    context.go('/news/${item.slug}');
  } else if (item.url != null) {
    launchUrl(Uri.parse(item.url!), mode: LaunchMode.externalApplication);
  }
}

// ---------------------------------------------------------------- /news

/// /news (and /news?topic=…): career news, tips and LuzHire guides.
class NewsPage extends ConsumerWidget {
  const NewsPage({super.key, this.topic});

  /// A category slug from [newsTopics], [luzhireTopic], or null for all.
  final String? topic;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final feed = ref.watch(newsFeedProvider(topic));
    final notifier = ref.read(newsFeedProvider(topic).notifier);
    final featured = topic == null
        ? (ref.watch(featuredNewsProvider).value ?? const <NewsItem>[])
        : const <NewsItem>[];
    final shownFeatured = {for (final f in featured) f.id};
    final rest = [
      for (final i in feed.items)
        if (!shownFeatured.contains(i.id)) i,
    ];

    void go(String? slug) =>
        context.go(pathWithQuery('/news', {'topic': ?slug}));

    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CAREER NEWS', style: t.eyebrow.copyWith(color: p.accent)),
            const SizedBox(height: LuzSpace.xs),
            Semantics(
              header: true,
              child: Text('News, tips and hiring trends', style: t.h2),
            ),
            const SizedBox(height: LuzSpace.xs),
            Text(
              'Fresh every morning from career publishers, plus guides from '
              'the LuzHire team.',
              style: t.body.copyWith(color: p.inkMuted),
            ),
            const SizedBox(height: LuzSpace.lg),
            Wrap(
              spacing: LuzSpace.xs,
              runSpacing: LuzSpace.xs,
              children: [
                LuzFilterChip(
                  label: 'All',
                  selected: topic == null,
                  onSelected: (_) => go(null),
                ),
                LuzFilterChip(
                  label: 'From LuzHire',
                  icon: Icons.auto_stories_outlined,
                  selected: topic == luzhireTopic,
                  onSelected: (_) => go(luzhireTopic),
                ),
                for (final tp in newsTopics)
                  LuzFilterChip(
                    label: tp.label,
                    icon: tp.icon,
                    selected: topic == tp.slug,
                    onSelected: (_) => go(tp.slug),
                  ),
              ],
            ),
            const SizedBox(height: LuzSpace.xl),
            if (featured.isNotEmpty) ...[
              _FeaturedRow(items: featured),
              const SizedBox(height: LuzSpace.xl),
            ],
            if (feed.isInitialLoad)
              LuzGrid(
                children: [for (var i = 0; i < 6; i++) const _NewsSkeleton()],
              )
            else if (feed.items.isEmpty && feed.error != null)
              JobBoardError(error: feed.error!, onRetry: notifier.loadMore)
            else if (feed.items.isEmpty)
              LuzEmptyState(
                icon: Icons.newspaper_outlined,
                title: 'Nothing here yet',
                message: topic == null
                    ? 'New stories arrive every morning.'
                    : 'No stories on this topic yet. Try another one.',
                actionLabel: topic == null ? null : 'Show all news',
                onAction: topic == null ? null : () => go(null),
              )
            else ...[
              if (featured.isNotEmpty && rest.isNotEmpty) ...[
                Semantics(
                  header: true,
                  child: Text('Latest stories', style: t.h3),
                ),
                const SizedBox(height: LuzSpace.md),
              ],
              LuzGrid(children: [for (final i in rest) NewsCard(item: i)]),
              LoadMoreFooter(
                loading: feed.loading,
                hasMore: feed.hasMore,
                error: feed.error,
                onLoadMore: notifier.loadMore,
                isEmpty: false,
                endLabel: '',
              ),
            ],
            const SizedBox(height: LuzSpace.lg),
            Text(
              'Headlines link to their publishers (Remotive, DEV Community, '
              'freeCodeCamp) and are chosen automatically for career topics.',
              style: t.caption.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The lead story large, the next featured ones as a compact list beside it
/// (stacked on narrow screens).
class _FeaturedRow extends StatelessWidget {
  const _FeaturedRow({required this.items});
  final List<NewsItem> items;

  @override
  Widget build(BuildContext context) {
    final lead = NewsCard(item: items.first, large: true);
    final others = [
      for (final i in items.skip(1)) ...[
        NewsListTile(item: i),
        const SizedBox(height: LuzSpace.sm),
      ],
    ];
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 900 || others.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              lead,
              if (others.isNotEmpty) ...[
                const SizedBox(height: LuzSpace.md),
                ...others,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: lead),
            const SizedBox(width: LuzSpace.lg),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'FEATURED',
                    style: context.luzText.eyebrow.copyWith(
                      color: context.luz.accent,
                    ),
                  ),
                  const SizedBox(height: LuzSpace.sm),
                  ...others,
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Source chip and date line shared by cards and tiles.
class _Byline extends StatelessWidget {
  const _Byline({required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return Wrap(
      spacing: LuzSpace.xs,
      runSpacing: LuzSpace.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        LuzStatusChip(
          label: newsSourceLabel(item.source),
          tone: item.isArticle ? LuzChipTone.orange : LuzChipTone.neutral,
          icon: item.isArticle ? Icons.auto_stories_outlined : null,
        ),
        Text(
          formatRelative(item.publishedAt),
          style: t.caption.copyWith(color: p.muted),
        ),
      ],
    );
  }
}

/// News card: image (or a topic tile), source, title, excerpt.
class NewsCard extends StatelessWidget {
  const NewsCard({super.key, required this.item, this.large = false});
  final NewsItem item;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final t = context.luzText;
    return LuzPressable(
      radius: LuzRadius.lg,
      semanticLabel:
          '${item.title}. ${newsSourceLabel(item.source)}, '
          '${formatRelative(item.publishedAt)}'
          '${item.isArticle ? '' : '. Opens the publisher\'s site'}',
      onPressed: () => openNews(context, item),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedLg
            : LuzDepth.raisedMd,
        radius: LuzRadius.lg,
        padding: const EdgeInsets.all(LuzSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NewsImage(item: item, aspectRatio: large ? 2 : 16 / 9),
            Padding(
              padding: const EdgeInsets.all(LuzSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Byline(item: item),
                  const SizedBox(height: LuzSpace.sm),
                  Text(
                    item.title,
                    style: large ? t.h3 : t.h4,
                    maxLines: large ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((item.summary ?? '').isNotEmpty) ...[
                    const SizedBox(height: LuzSpace.xs),
                    Text(
                      item.summary!,
                      style: t.bodySm.copyWith(color: p.inkMuted),
                      maxLines: large ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: LuzSpace.sm),
                  Row(
                    children: [
                      Icon(
                        item.isArticle ? Icons.schedule : Icons.open_in_new,
                        size: 16,
                        color: p.accent,
                      ),
                      const SizedBox(width: LuzSpace.xxs),
                      Flexible(
                        child: Text(
                          item.isArticle
                              ? 'Read the guide'
                              : 'Read on ${newsSourceLabel(item.source)}',
                          style: t.label.copyWith(color: p.accent),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact row: thumbnail, title and byline.
class NewsListTile extends StatelessWidget {
  const NewsListTile({super.key, required this.item});
  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    return LuzPressable(
      radius: LuzRadius.md,
      semanticLabel: '${item.title}. ${newsSourceLabel(item.source)}',
      onPressed: () => openNews(context, item),
      builder: (context, pressed, hovered) => LuzSurface(
        depth: pressed
            ? LuzDepth.insetSm
            : hovered
            ? LuzDepth.raisedMd
            : LuzDepth.raisedSm,
        radius: LuzRadius.md,
        padding: const EdgeInsets.all(LuzSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              child: NewsImage(item: item, aspectRatio: 4 / 3),
            ),
            const SizedBox(width: LuzSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: t.wsCardTitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: LuzSpace.xs),
                  _Byline(item: item),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The feed's image, or a tile with the topic's icon when there is none or
/// it fails to load.
class NewsImage extends StatelessWidget {
  const NewsImage({super.key, required this.item, this.aspectRatio = 16 / 9});
  final NewsItem item;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final p = context.luz;
    final topic = item.categories.map(newsTopic).nonNulls.firstOrNull;
    final tile = DecoratedBox(
      decoration: BoxDecoration(
        color: p.sunken,
        border: Border.all(color: p.hairline),
        borderRadius: BorderRadius.circular(LuzRadius.md),
      ),
      child: Center(
        child: Icon(
          item.isArticle
              ? Icons.auto_stories_outlined
              : topic?.icon ?? Icons.newspaper_outlined,
          size: 36,
          color: p.accent,
        ),
      ),
    );
    return ExcludeSemantics(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: item.imageUrl == null
            ? tile
            : ClipRRect(
                borderRadius: BorderRadius.circular(LuzRadius.md),
                child: LayoutBuilder(
                  builder: (context, c) => Image.network(
                    networkImageUrl(item.imageUrl!),
                    fit: BoxFit.cover,
                    cacheWidth:
                        (c.maxWidth * MediaQuery.devicePixelRatioOf(context))
                            .ceil(),
                    errorBuilder: (_, _, _) => tile,
                  ),
                ),
              ),
      ),
    );
  }
}

class _NewsSkeleton extends StatelessWidget {
  const _NewsSkeleton();

  @override
  Widget build(BuildContext context) => const LuzSurface(
    depth: LuzDepth.raisedMd,
    radius: LuzRadius.lg,
    padding: EdgeInsets.all(LuzSpace.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: LuzSkeleton(radius: LuzRadius.md),
        ),
        SizedBox(height: LuzSpace.md),
        LuzSkeleton(width: 90),
        SizedBox(height: LuzSpace.sm),
        LuzSkeleton(height: 18),
        SizedBox(height: LuzSpace.xs),
        LuzSkeleton(width: 180),
      ],
    ),
  );
}

// ---------------------------------------------------------------- article

/// /news/:slug: a LuzHire article.
class NewsArticlePage extends ConsumerWidget {
  const NewsArticlePage({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(newsArticleProvider(slug));
    return article.when(
      loading: () => const Center(child: LuzSkeleton(width: 220, height: 16)),
      error: (e, _) => Center(
        child: JobBoardError(
          error: mapDbError(e),
          onRetry: () => ref.invalidate(newsArticleProvider(slug)),
        ),
      ),
      data: (a) => a == null
          ? Center(
              child: LuzEmptyState(
                icon: Icons.newspaper_outlined,
                title: 'This article is not available',
                message: 'It may have been unpublished.',
                actionLabel: 'All news',
                onAction: () => context.go('/news'),
              ),
            )
          : _ArticleBody(article: a),
    );
  }
}

class _ArticleBody extends ConsumerWidget {
  const _ArticleBody({required this.article});
  final NewsItem article;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.luz;
    final t = context.luzText;
    final topic = article.categories.map(newsTopic).nonNulls.firstOrNull;
    final more = ref
        .watch(newsFeedProvider(luzhireTopic))
        .items
        .where((i) => i.id != article.id)
        .take(3)
        .toList();
    return SingleChildScrollView(
      child: LuzContent(
        vertical: LuzSpace.xl,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LuzTextLink(
                  label: '← All news',
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/news'),
                ),
                const SizedBox(height: LuzSpace.lg),
                Text(
                  (topic?.label ?? 'LuzHire guide').toUpperCase(),
                  style: t.eyebrow.copyWith(color: p.accent),
                ),
                const SizedBox(height: LuzSpace.xs),
                Semantics(
                  header: true,
                  child: Text(article.title, style: t.h1),
                ),
                const SizedBox(height: LuzSpace.sm),
                Wrap(
                  spacing: LuzSpace.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'By ${article.authorName ?? 'LuzHire'}',
                      style: t.label,
                    ),
                    Text(
                      '${DateFormat('d MMM y').format(article.publishedAt.toLocal())}'
                      ' · ${article.readMinutes} min read',
                      style: t.bodySm.copyWith(color: p.inkMuted),
                    ),
                    if (!article.isPublished)
                      const LuzStatusChip(
                        label: 'Draft',
                        tone: LuzChipTone.neutral,
                        icon: Icons.edit_note,
                      ),
                    LuzIconButton(
                      icon: Icons.link,
                      tooltip: 'Copy link',
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(
                            text: '${Uri.base.origin}/news/${article.slug}',
                          ),
                        );
                        if (context.mounted) {
                          showLuzToast(
                            context,
                            'Link copied',
                            icon: Icons.check,
                          );
                        }
                      },
                    ),
                  ],
                ),
                if ((article.summary ?? '').isNotEmpty) ...[
                  const SizedBox(height: LuzSpace.lg),
                  Text(
                    article.summary!,
                    style: t.bodyLg.copyWith(color: p.inkMuted),
                  ),
                ],
                const SizedBox(height: LuzSpace.lg),
                SimpleMarkdown(article.bodyMd ?? ''),
                if (more.isNotEmpty) ...[
                  const SizedBox(height: LuzSpace.xl),
                  Semantics(
                    header: true,
                    child: Text('More from LuzHire', style: t.h4),
                  ),
                  const SizedBox(height: LuzSpace.sm),
                  for (final m in more) ...[
                    NewsListTile(item: m),
                    const SizedBox(height: LuzSpace.sm),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- home

/// Home: the three newest stories, hidden while there are none.
class HomeNewsSection extends ConsumerWidget {
  const HomeNewsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(newsFeedProvider(null)).items.take(3).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    final p = context.luz;
    final t = context.luzText;
    return LuzContent(
      vertical: LuzSpace.xl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CAREER NEWS', style: t.eyebrow.copyWith(color: p.accent)),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: LuzSpace.md,
            children: [
              Text('Tips and trends this week', style: t.h3),
              LuzTextLink(
                label: 'All news →',
                onPressed: () => context.go('/news'),
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.lg),
          LuzGrid(children: [for (final i in items) NewsCard(item: i)]),
        ],
      ),
    );
  }
}
