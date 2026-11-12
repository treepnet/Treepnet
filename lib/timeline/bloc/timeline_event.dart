part of 'timeline_bloc.dart';

sealed class TimelineEvent extends Equatable {
  const TimelineEvent();

  @override
  List<Object?> get props => [];
}

final class TimelinePageRequested extends TimelineEvent {
  const TimelinePageRequested({this.page});

  final int? page;

  @override
  List<Object?> get props => [page];
}

final class TimelineRefreshRequested extends TimelineEvent {
  const TimelineRefreshRequested();
}

/// Posts deleted, hidden or archived, or a blocked author's: they leave the
/// grid (see [PostRemoval]).
final class TimelinePostsRemoved extends TimelineEvent {
  const TimelinePostsRemoved(this.removal);

  final PostRemoval removal;

  @override
  List<Object?> get props => [removal];
}
