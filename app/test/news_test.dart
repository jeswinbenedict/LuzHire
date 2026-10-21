import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:luzhire/core/data/enums.dart';
import 'package:luzhire/core/widgets/widgets.dart';
import 'package:luzhire/features/news/presentation/news_pages.dart';

import 'support/admin_fakes.dart';
import 'support/candidate_fakes.dart';
import 'support/employer_fakes.dart';
import 'support/fakes.dart';
import 'support/job_fakes.dart';
import 'support/news_fakes.dart';

Future<GoRouter> _pump(
  WidgetTester tester, {
  required String location,
  double width = 1280,
  FakeNewsRepository? news,
  AppRole? signedIn,
}) => pumpLuzHire(
  tester,
  location: location,
  size: Size(width, 1000),
  gateway: FakeAuthGateway(
    signedIn: signedIn == null ? null : signedInAs(signedIn),
  ),
  overrides: [
    ...jobBoardOverrides(),
    ...newsOverrides(news),
    if (signedIn == AppRole.admin) ...[
      ...CandidateFakes().overrides,
      ...employerOverrides(FakeEmployerRepository()),
      ...adminOverrides(FakeAdminRepository()),
    ],
  ],
);

Finder _field(String label) => find.descendant(
  of: find.widgetWithText(LuzTextField, label),
  matching: find.byType(TextField),
);

void main() {
  group('/news', () {
    for (final width in [360.0, 768.0, 1440.0]) {
      testWidgets('lists stories at ${width.toInt()} px', (tester) async {
        await _pump(tester, location: '/news', width: width);
        expect(find.text('News, tips and hiring trends'), findsOneWidget);
        expect(find.text('Headline 1 about careers'), findsOneWidget);
        expect(find.text('How to ace your campus drive'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('the featured story leads and is not repeated', (tester) async {
      await _pump(tester, location: '/news', width: 1440);
      final lead = tester.widget<NewsCard>(find.byType(NewsCard).first);
      expect(lead.large, isTrue);
      expect(lead.item.id, 'h-1');
      expect(find.text('Headline 1 about careers'), findsOneWidget);
      expect(find.text('Latest stories'), findsOneWidget);
    });

    testWidgets('topics filter the stories and live in the URL', (
      tester,
    ) async {
      final router = await _pump(tester, location: '/news');
      await tester.tap(find.text('Remote work'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/news?topic=remote-work');
      expect(find.text('Headline 2 about careers'), findsOneWidget);
      expect(find.text('Headline 3 about careers'), findsNothing);
      expect(find.text('Read on Remotive'), findsOneWidget);
    });

    testWidgets('an empty topic offers the way back', (tester) async {
      final router = await _pump(tester, location: '/news?topic=skills');
      expect(find.text('Nothing here yet'), findsOneWidget);
      await tester.tap(find.text('Show all news'));
      await tester.pumpAndSettle();
      expect(router.state.uri.toString(), '/news');
    });

    testWidgets('"From LuzHire" opens an article in the app', (tester) async {
      final router = await _pump(tester, location: '/news?topic=luzhire');
      expect(find.text('Headline 4 about careers'), findsNothing);
      await tester.tap(find.text('How to ace your campus drive'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/news/ace-your-campus-drive');
      expect(find.text('By Ada Admin'), findsOneWidget);
      expect(find.text('Before the drive'), findsOneWidget);
      expect(find.text('Research the company'), findsOneWidget);
      expect(find.textContaining('min read'), findsOneWidget);
    });

    testWidgets('an unknown article says so', (tester) async {
      await _pump(tester, location: '/news/nope');
      expect(find.text('This article is not available'), findsOneWidget);
    });

    testWidgets('home shows the newest stories', (tester) async {
      await _pump(tester, location: '/');
      expect(find.text('Tips and trends this week'), findsOneWidget);
      expect(find.byType(NewsCard), findsNWidgets(3));
    });
  });

  group('/admin/news', () {
    testWidgets('admins write and publish an article', (tester) async {
      final news = FakeNewsRepository();
      await _pump(
        tester,
        location: '/admin/news',
        width: 1440,
        news: news,
        signedIn: AppRole.admin,
      );
      expect(find.text('How to ace your campus drive'), findsOneWidget);

      await tester.tap(find.text('New article'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publish'));
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(find.text('Write the article'), findsOneWidget);
      expect(find.text('Pick at least one topic'), findsOneWidget);
      expect(news.saved, isEmpty);

      await tester.enterText(_field('Title'), 'Resume mistakes freshers make');
      await tester.enterText(
        _field('Article (Markdown: ## headings, - bullets, **bold**)'),
        '## Keep it to one page',
      );
      await tester.ensureVisible(find.text('Interviews & CVs'));
      await tester.tap(find.text('Interviews & CVs'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Publish'));
      await tester.tap(find.text('Publish'));
      await tester.pumpAndSettle();
      expect(news.saved.single, {
        'id': null,
        'title': 'Resume mistakes freshers make',
        'body': '## Keep it to one page',
        'categories': ['interviews'],
        'featured': false,
        'publish': true,
      });
      expect(find.text('Resume mistakes freshers make'), findsOneWidget);
    });

    testWidgets('admins feature and hide imported headlines', (tester) async {
      final news = FakeNewsRepository();
      await _pump(
        tester,
        location: '/admin/news',
        width: 1440,
        news: news,
        signedIn: AppRole.admin,
      );
      await tester.tap(find.text('Imported headlines'));
      await tester.pumpAndSettle();
      expect(find.text('Headline 2 about careers'), findsOneWidget);
      await tester.tap(find.text('Hide').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unfeature'));
      await tester.pumpAndSettle();
      expect(news.curated, [('h-1', null, false), ('h-1', false, null)]);
    });
  });
}
