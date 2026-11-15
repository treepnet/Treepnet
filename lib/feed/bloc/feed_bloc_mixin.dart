part of 'feed_bloc.dart';

// A typedef representing the result of a paginated feed.
typedef PaginatedFeedResult =
    Future<({int newPage, bool hasMore, List<InstaBlock> blocks})>;

/// A feed page the server couldn't send ([PostsPageIncomplete]), as blocks:
/// [blocks] are the posts the phone had for it. The same page is asked for
/// again on Retry, so the page number doesn't move on.
class FeedPageIncomplete implements Exception {
  /// A page whose server part failed with [cause].
  const FeedPageIncomplete(this.blocks, this.cause);

  /// The page's posts that came from the phone.
  final List<InstaBlock> blocks;

  /// Why the server part failed.
  final Object cause;
}

/// Represents the different types of page updates.
///
/// This enum defines three types of page updates: create, delete, and update.
/// It also provides convenient boolean getters to check the type of the update.
/// - `isCreate` returns true if the update is of type create.
/// - `isDelete` returns true if the update is of type delete.
/// - `isUpdate` returns true if the update is of type update.
enum PageUpdateType {
  create,
  delete,
  update;

  bool get isCreate => this == PageUpdateType.create;
  bool get isDelete => this == PageUpdateType.delete;
  bool get isUpdate => this == PageUpdateType.update;
}

/// {@template page_update}
/// Represents a page update.
///
/// This class encapsulates information about a page update, including the new
/// post and the type of update.
/// It provides a getter for the new large block derived from the new post.
/// The `onUpdate` method can be used to update a block with a new block.
/// The boolean getters `isCreate`, `isDelete`, and `isUpdate` can be used to
/// check the type of the update.
///
/// Example usage:
/// ```dart
/// final update = PageUpdate(newPost: post, type: PageUpdateType.create);
/// final newLargeBlock = update.newLargeBlock;
/// final updatedBlock = update.onUpdate(oldBlock, newBlock);
/// final isCreate = update.isCreate;
/// ```
///
/// See also:
/// - `Post` class for representing a post
/// - `PageUpdateType` enum for representing the type of a page update
/// - `PostLargeBlock` class for representing a large block of a post
/// {@endtemplate}
sealed class PageUpdate {
  const PageUpdate({required this.newPost, required this.type});

  final Post newPost;
  final PageUpdateType type;

  /// Returns the new large block derived from the `newPost` by calling the
  /// `toPostLargeBlock()` method.
  PostLargeBlock get newLargeBlock => newPost.toPostLargeBlock;

  /// Updates a [PostBlock] with a new block.
  ///
  /// This method takes in a [block] of type [T] and a [newBlock] of type
  /// [PostBlock] and returns a new [PostBlock] that is updated based on the
  /// provided [newBlock].
  ///
  /// Example usage:
  /// ```dart
  /// final updatedBlock = onUpdate<PostLargeBlock>(block, newBlock);
  /// ```
  ///
  /// Note: The [block] and [newBlock] should have the same type [T].
  /// If the [block] and [newBlock] have different types, the method will throw
  /// an error.
  ///
  PostBlock onUpdate<T>(T block, PostBlock newBlock);

  bool get isCreate => type.isCreate;
  bool get isDelete => type.isDelete;
  bool get isUpdate => type.isUpdate;
}

/// {@template feed_page_update}
/// Represents a page update for the feed.
///
/// This class extends the [PageUpdate] class and provides an implementation
/// for the [onUpdate] method. It is specifically used for updating the feed
/// page.
///
/// The [onUpdate] method takes in a `block` of type `T` and a `newBlock` of
/// type [PostBlock] and returns a new [PostBlock] that is updated based on
/// the provided `newBlock`. If the `block` is of any other type, it throws an
/// [UnsupportedError] with a message indicating the unsupported block type.
/// {@endtemplate}
final class FeedPageUpdate extends PageUpdate {
  const FeedPageUpdate({required super.newPost, required super.type});

  @override
  PostBlock onUpdate<T>(T block, PostBlock newBlock) => switch (block) {
    final PostLargeBlock block => block.copyWith(caption: newBlock.caption),
    _ => throw UnsupportedError('Unsupported block type: $block'),
  };
}

/// {@template feed_bloc_mixin}
/// A mixin class that provides common functionality for a feed bloc.
///
/// This mixin class is intended to be used with a `Bloc` class that handles
/// feed-related events and states.
/// It provides methods and properties for fetching feed pages, getting posts
/// by ID, updating blocks, and inserting sponsored blocks.
///
/// To use this mixin, implement the necessary dependencies:
/// - `PostsRepository` for fetching posts and post likers
///
/// Example usage:
/// ```dart
/// class MyFeedBloc extends Bloc<FeedEvent, FeedState> with FeedBlocMixin {
///   // Implement necessary dependencies
///   PostsRepository get postsRepository => ...
///
///   // Implement other methods and properties specific to your feed bloc
///   ...
/// }
/// ```
///
/// Note: This mixin assumes that the `Bloc` class has already implemented the
///  necessary event and state classes for feed-related functionality.
/// It also assumes that the `PostsRepository` and
/// initialized.
///
/// See also:
/// - `Bloc` class for handling feed-related events and states
/// - `PostsRepository` class for fetching posts and post likers
/// {@endtemplate}
mixin FeedBlocMixin on Bloc<FeedEvent, FeedState> {
  /// Posts per feed page. It was 7: a fast scroll met the spinner every 7
  /// posts, each page past the people you follow a round trip to Frankfurt.
  /// The next page is asked for 3 posts before the end (feed_page.dart).
  int get feedPageLimit => 15;

  PostsRepository get postsRepository;

  /// Retrieves a post block by its ID.
  ///
  /// Example:
  /// ```dart
  /// final postBlock = await getPostBy('123');
  /// ```
  ///
  /// Note: This method internally calls the `getPostBy` method of the
  /// `postsRepository` to fetch the post by its ID and converts it to a
  /// `PostLargeBlock`.
  /// If the post is not found, it returns `null`.
  ///
  Future<PostBlock?> getPostBy(String id) async {
    final post = await postsRepository.getPostBy(id: id);
    return post?.toPostLargeBlock;
  }

  /// Fetches a paginated feed page.
  ///
  ///
  /// Throws:
  /// - Any error that occurs during the fetching process.
  ///
  /// Example usage:
  /// ```dart
  /// final (:newPage, :hasMore, :blocks) = await fetchFeedPage(page: 1);
  ///
  /// print(newPage);
  /// print(hasMore);
  /// print(blocks);
  /// ```
  ///
  PaginatedFeedResult fetchFeedPage({int page = 0}) async {
    final currentPage = page;
    const toBlocks = postsToLargeBlocksMapper;
    // People you follow and your own posts first, then everyone else's.
    final List<Post> posts;
    try {
      posts = await postsRepository.getPage(
        offset: currentPage * feedPageLimit,
        limit: feedPageLimit,
        order: PostOrder.feed,
      );
    } on PostsPageIncomplete catch (incomplete) {
      throw FeedPageIncomplete(toBlocks(incomplete.posts), incomplete.cause);
    }
    final newPage = currentPage + 1;
    final hasMore = posts.length >= feedPageLimit;

    return (newPage: newPage, hasMore: hasMore, blocks: toBlocks(posts));
  }

  /// Converts a list of [Post] objects.
  ///
  /// Example usage:
  /// ```dart
  /// List<Post> posts = [...];
  /// List<InstaBlock> instaBlocks = postsToLargeBlocksMapper(posts);
  /// ```
  static List<InstaBlock> postsToLargeBlocksMapper(List<Post> posts) =>
      posts.map<InstaBlock>((post) => post.toPostLargeBlock).toList();
}

extension on Feed {
  List<PostBlock> updateFeedPage({required PageUpdate update}) {
    try {
      return feedPage.blocks.selectPostsBlock().updateBlocks(update: update);
    } catch (_) {
      rethrow;
    }
  }
}

extension on List<InstaBlock> {
  List<PostBlock> selectPostsBlock() => whereType<PostBlock>().toList();

  InstaBlock? findPostBlock({
    PostBlock? other,
    bool Function(PostBlock block)? test,
  }) => firstWhereOrNull(
    (block) => switch (block) {
      final PostBlock block =>
        (other == null || other.id == block.id) && (test?.call(block) ?? true),
      _ => false,
    },
  );
}

extension on List<PostBlock> {
  List<PostBlock> updateBlocks({required PageUpdate update}) =>
      switch (update) {
        final FeedPageUpdate update => _update<PostLargeBlock>(update: update),
      };

  List<PostBlock> _update<T extends PostBlock>({required PageUpdate update}) {
    try {
      return updateWith<T>(
        newItem: update.newLargeBlock,
        onUpdate: update.onUpdate,
        isDelete: update.type.isDelete,
        findItemCallback: (block, newBlock) => block.id == newBlock.id,
      );
    } catch (_) {
      rethrow;
    }
  }
}
