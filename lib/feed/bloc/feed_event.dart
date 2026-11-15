part of 'feed_bloc.dart';

sealed class FeedEvent extends Equatable {
  const FeedEvent();

  @override
  List<Object?> get props => [];
}

sealed class FeedPageBasedEvent extends FeedEvent {
  const FeedPageBasedEvent({this.page});

  final int? page;

  @override
  List<Object?> get props => [page];
}

final class FeedPageRequested extends FeedPageBasedEvent {
  const FeedPageRequested({super.page});
}

final class FeedUpdateRequested extends FeedEvent {
  const FeedUpdateRequested({required this.update});

  final PageUpdate update;

  @override
  List<Object?> get props => [update];
}

/// The signed-in account changed: the feed starts empty, not with the last
/// account's posts.
final class FeedResetRequested extends FeedEvent {
  const FeedResetRequested();
}

final class FeedRefreshRequested extends FeedEvent {
  const FeedRefreshRequested();
}
