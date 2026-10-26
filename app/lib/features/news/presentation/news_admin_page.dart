import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/data/format.dart';
import '../../../core/data/models.dart';
import '../../../core/shell/workspace_page.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../candidate/presentation/candidate_widgets.dart'
    show AsyncBlock, runWithToast;
import '../application/news_providers.dart';
import '../data/news_repository.dart';
import 'news_pages.dart' show openNews;

/// /admin/news: write LuzHire articles and curate imported headlines.
class NewsAdminPage extends ConsumerStatefulWidget {
  const NewsAdminPage({super.key});

  @override
  ConsumerState<NewsAdminPage> createState() => _NewsAdminPageState();
}

class _NewsAdminPageState extends ConsumerState<NewsAdminPage> {
  bool _articles = true;

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminNewsProvider(_articles));
    return WorkspacePage(
      subtitle: 'Articles by the LuzHire team and headlines imported daily',
      actions: [
        LuzButton.accent(
          label: 'New article',
          icon: Icons.add,
          onPressed: () => _edit(context, null),
        ),
      ],
      children: [
        LuzSegmented<bool>(
          segments: const [
            (value: true, label: 'Articles', icon: Icons.auto_stories_outlined),
            (value: false, label: 'Imported headlines', icon: Icons.rss_feed),
          ],
          selected: _articles,
          onChanged: (v) => setState(() => _articles = v),
        ),
        // WorkspacePage spaces its children.
        AsyncBlock<List<NewsItem>>(
          value: list,
          onRetry: () => ref.invalidate(adminNewsProvider(_articles)),
          data: (items) => items.isEmpty
              ? LuzEmptyState(
                  icon: _articles
                      ? Icons.auto_stories_outlined
                      : Icons.rss_feed,
                  title: _articles
                      ? 'No articles yet'
                      : 'No headlines imported yet',
                  message: _articles
                      ? 'Write career guides for candidates. They appear '
                            'under "From LuzHire" on /news.'
                      : 'The import runs every morning.',
                )
              : Column(
                  children: [
                    for (final n in items) ...[
                      _NewsRow(item: n, onEdit: () => _edit(context, n)),
                      const SizedBox(height: LuzSpace.md),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, NewsItem? item) =>
      showLuzModal<void>(
        context: context,
        title: item == null ? 'New article' : 'Edit article',
        builder: (_) => _ArticleForm(existing: item),
      );
}

class _NewsRow extends ConsumerWidget {
  const _NewsRow({required this.item, required this.onEdit});
  final NewsItem item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.luzText;
    final p = context.luz;
    final actions = ref.read(newsActionsProvider);
    return LuzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: LuzSpace.xs,
            runSpacing: LuzSpace.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              LuzStatusChip(
                label: item.isPublished
                    ? (item.isArticle ? 'Published' : 'Shown')
                    : (item.isArticle ? 'Draft' : 'Hidden'),
                tone: item.isPublished
                    ? LuzChipTone.green
                    : LuzChipTone.neutral,
              ),
              if (item.isFeatured)
                const LuzStatusChip(
                  label: 'Featured',
                  tone: LuzChipTone.orange,
                  icon: Icons.star_outline,
                ),
              LuzStatusChip(
                label: newsSourceLabel(item.source),
                tone: LuzChipTone.blue,
              ),
            ],
          ),
          const SizedBox(height: LuzSpace.xs),
          Text(item.title, style: t.wsSection),
          if ((item.summary ?? '').isNotEmpty)
            Text(
              item.summary!,
              style: t.bodySm,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            formatRelative(item.publishedAt),
            style: t.caption.copyWith(color: p.muted),
          ),
          const SizedBox(height: LuzSpace.xs),
          Wrap(
            spacing: LuzSpace.md,
            children: [
              LuzTextLink(
                label: item.isArticle ? 'Open' : 'Open source',
                onPressed: () => openNews(context, item),
              ),
              if (item.isArticle) LuzTextLink(label: 'Edit', onPressed: onEdit),
              LuzTextLink(
                label: item.isFeatured ? 'Unfeature' : 'Feature',
                onPressed: () => runWithToast(
                  context,
                  () => actions.curate(item.id, featured: !item.isFeatured),
                  success: item.isFeatured
                      ? 'No longer featured'
                      : 'Featured on /news',
                ),
              ),
              if (!item.isArticle)
                LuzTextLink(
                  label: item.isPublished ? 'Hide' : 'Show',
                  onPressed: () => runWithToast(
                    context,
                    () => actions.curate(item.id, published: !item.isPublished),
                    success: item.isPublished ? 'Hidden' : 'Shown again',
                  ),
                ),
              if (item.isArticle)
                LuzTextLink(
                  label: 'Delete',
                  onPressed: () async {
                    final ok = await confirmLuz(
                      context,
                      title: 'Delete "${item.title}"?',
                      message: 'Its link stops working for everyone.',
                      confirmLabel: 'Delete',
                      icon: Icons.delete_outline,
                    );
                    if (ok && context.mounted) {
                      await runWithToast(
                        context,
                        () => actions.delete(item.id),
                      );
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArticleForm extends ConsumerStatefulWidget {
  const _ArticleForm({this.existing});
  final NewsItem? existing;

  @override
  ConsumerState<_ArticleForm> createState() => _ArticleFormState();
}

class _ArticleFormState extends ConsumerState<_ArticleForm> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _summary = TextEditingController(text: widget.existing?.summary);
  late final _body = TextEditingController(text: widget.existing?.bodyMd);
  late final _topics = <String>{...?widget.existing?.categories};
  late bool _featured = widget.existing?.isFeatured ?? false;
  late bool _publish = widget.existing?.isPublished ?? true;
  final _errors = <String, String?>{};
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _summary.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    setState(() {
      _errors
        ..['title'] = title.length < 4 ? 'Use at least 4 characters' : null
        ..['body'] = _body.text.trim().isEmpty ? 'Write the article' : null
        ..['topics'] = _topics.isEmpty ? 'Pick at least one topic' : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _busy = true);
    final ok = await runWithToast(
      context,
      () => ref
          .read(newsActionsProvider)
          .saveArticle(
            id: widget.existing?.id,
            title: title,
            summary: _summary.text,
            bodyMd: _body.text,
            categories: [
              for (final tp in newsTopics)
                if (_topics.contains(tp.slug)) tp.slug,
            ],
            featured: _featured,
            publish: _publish,
          ),
      success: _publish ? 'Article published' : 'Draft saved',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.luzText;
    final p = context.luz;
    const gap = SizedBox(height: LuzSpace.md);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LuzTextField(
          label: 'Title',
          controller: _title,
          error: _errors['title'],
          maxLength: 160,
          autofocus: true,
        ),
        gap,
        LuzTextField(
          label: 'Summary (shown on cards)',
          controller: _summary,
          maxLines: 3,
          maxLength: 400,
        ),
        gap,
        LuzTextField(
          label: 'Article (Markdown: ## headings, - bullets, **bold**)',
          controller: _body,
          error: _errors['body'],
          maxLines: 14,
          maxLength: 40000,
        ),
        gap,
        Text('Topics', style: t.label),
        const SizedBox(height: LuzSpace.xs),
        Wrap(
          spacing: LuzSpace.xs,
          runSpacing: LuzSpace.xs,
          children: [
            for (final tp in newsTopics)
              LuzFilterChip(
                label: tp.label,
                icon: tp.icon,
                selected: _topics.contains(tp.slug),
                onSelected: (on) => setState(
                  () => on ? _topics.add(tp.slug) : _topics.remove(tp.slug),
                ),
              ),
          ],
        ),
        if (_errors['topics'] != null)
          Padding(
            padding: const EdgeInsets.only(top: LuzSpace.xxs),
            child: Text(
              _errors['topics']!,
              style: t.bodySm.copyWith(color: p.danger),
            ),
          ),
        gap,
        Row(
          children: [
            Expanded(child: Text('Feature on /news', style: t.label)),
            LuzToggle(
              value: _featured,
              semanticLabel: 'Feature on /news',
              onChanged: (v) => setState(() => _featured = v),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(child: Text('Publish now', style: t.label)),
            LuzToggle(
              value: _publish,
              semanticLabel: 'Publish now',
              onChanged: (v) => setState(() => _publish = v),
            ),
          ],
        ),
        gap,
        LuzButton.accent(
          label: _busy ? 'Saving…' : (_publish ? 'Publish' : 'Save draft'),
          expand: true,
          onPressed: _busy ? null : _save,
        ),
        if (widget.existing?.slug != null) ...[
          const SizedBox(height: LuzSpace.sm),
          LuzTextLink(
            label: 'Preview /news/${widget.existing!.slug}',
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/news/${widget.existing!.slug}');
            },
          ),
        ],
      ],
    );
  }
}
