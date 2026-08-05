part of 'create_stories_bloc.dart';

enum CreateStoriesStatus { initial, loading, success, failure }

class CreateStoriesState extends Equatable {
  const CreateStoriesState._({required this.status});

  const CreateStoriesState.initial()
    : this._(status: CreateStoriesStatus.initial);

  final CreateStoriesStatus status;

  @override
  List<Object?> get props => [status];

  CreateStoriesState copyWith({CreateStoriesStatus? status}) {
    return CreateStoriesState._(status: status ?? this.status);
  }
}
