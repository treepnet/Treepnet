import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:bloc/bloc.dart';
import 'package:shared/shared.dart';
import 'package:stories_repository/stories_repository.dart';
import 'package:user_repository/user_repository.dart';

part 'user_stories_event.dart';
part 'user_stories_state.dart';

class UserStoriesBloc extends Bloc<UserStoriesEvent, UserStoriesState> {
  UserStoriesBloc({
    required User author,
    required StoriesRepository storiesRepository,
  }) : _author = author,
       _storiesRepository = storiesRepository,
       super(const UserStoriesState.initial()) {
    on<UserStoriesSubscriptionRequested>(
      _onUserStoriesSubscriptionRequested,
      // The handler keeps its subscription open for good: a pull-to-refresh
      // adding another must replace it, not stack one more on top.
      transformer: restartable(),
    );
  }

  final User _author;
  final StoriesRepository _storiesRepository;


  Future<void> _onUserStoriesSubscriptionRequested(
    UserStoriesSubscriptionRequested event,
    Emitter<UserStoriesState> emit,
  ) async {
    emit(state.copyWith(author: _author));
    await emit.forEach(
      _storiesRepository.mergedStories(
        authorId: _author.id,
        userId: event.userId,
      ),
      onData: (stories) => state.copyWith(
        stories: stories,
        showStories: stories.any((e) => !e.seen),
      ),
    );
  }
}
