import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:posts_repository/posts_repository.dart';
import 'package:shared/shared.dart';
import 'package:treepnet/feed/new_feed/feed_post_place.dart';
import 'package:treepnet/l10n/l10n.dart';
import 'package:treepnet/map/geo_regions.dart';

class _MockPostsRepository extends Mock implements PostsRepository {}

/// The new feed (a prototype): under the globe, where the buttons were, the
/// globe's white pin and the post's country and city.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The country and the city come from the map data.
  setUpAll(() async => GeoRegions.instance.load());

  late _MockPostsRepository posts;

  setUp(() => posts = _MockPostsRepository());

  PostLargeBlock post({String? location}) => PostLargeBlock(
    id: 'post-1',
    author: const PostAuthor(id: 'author', avatarUrl: '', username: 'author'),
    createdAt: DateTime(2026),
    media: const [ImageMedia(id: 'm1', url: '')],
    caption: '',
    location: location,
  );

  /// The post's pin, in Tashkent unless [lat]/[lng] say otherwise.
  void pinNamed(String? name, {double lat = 41.31, double lng = 69.28}) =>
      when(() => posts.travelMapOf(userId: 'author')).thenAnswer(
        (_) async => TravelMap(
          regions: const {},
          pins: [(postId: 'post-1', lat: lat, lng: lng, name: name)],
        ),
      );

  Future<void> pump(
    WidgetTester tester,
    PostBlock block, {
    String lang = 'en',
  }) async {
    await tester.pumpWidget(
      RepositoryProvider<PostsRepository>.value(
        value: posts,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(lang),
          home: Scaffold(body: FeedPostPlace(block: block)),
        ),
      ),
    );
    await tester.pump();
  }

  GeoRegion tashkent() => GeoRegions.instance.regionAt(69.28, 41.31)!;

  for (final name in ['Magic City', null, 'Tashkent, Uzbekistan']) {
    testWidgets('the country and the city, never the spot ($name)', (
      tester,
    ) async {
      pinNamed(name);
      await pump(tester, post(location: 'Tashkent'));
      final city = tashkent();
      expect(city.localizedCountryName('en'), 'Uzbekistan');
      expect(
        find.text(
          '${city.localizedCountryName('en')}, '
          '${city.localizedDisplayName('en')}',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Magic City'), findsNothing);
      final pin = tester.widget<Icon>(find.byIcon(Icons.location_on));
      expect(pin.color, Colors.white);
    });
  }

  testWidgets("the country and the city in the app's language", (tester) async {
    pinNamed('Magic City');
    await pump(tester, post(location: 'Tashkent'), lang: 'ru');
    final city = tashkent();
    expect(
      find.text(
        '${city.localizedCountryName('ru')}, '
        '${city.localizedDisplayName('ru')}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('out at sea: the region as saved', (tester) async {
    pinNamed('Ferry', lat: 40, lng: -40);
    await pump(tester, post(location: 'Tashkent'));
    expect(find.text('Tashkent'), findsOneWidget);
    expect(find.textContaining('Ferry'), findsNothing);
  });

  testWidgets('no name at all: nothing', (tester) async {
    pinNamed(null, lat: 40, lng: -40);
    await pump(tester, post());
    expect(find.byIcon(Icons.location_on), findsNothing);
  });
}
