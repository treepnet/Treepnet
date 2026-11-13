part of 'user_stories_bloc.dart';

@immutable
class UserStoriesState extends Equatable {
  const UserStoriesState({
    required this.author,
    required this.stories,
    required this.showStories,
  });

  const UserStoriesState.initial()
    : this(author: User.anonymous, stories: const [], showStories: false);

  final User author;
  final List<Story> stories;
  final bool showStories;

  @override
  List<Object?> get props => [author, stories, showStories];

  UserStoriesState copyWith({
    User? author,
    List<Story>? stories,
    bool? showStories,
  }) {
    return UserStoriesState(
      author: author ?? this.author,
      stories: stories ?? this.stories,
      showStories: showStories ?? this.showStories,
    );
  }
}
