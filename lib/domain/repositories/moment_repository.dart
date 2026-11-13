import 'package:native_tavern/data/models/moment/moment_post.dart';

/// Storage-independent operations for the public moments feed.
abstract interface class MomentRepository {
  Future<MomentPost?> getById(String id);

  Future<MomentPost> create(MomentPost post);

  Future<MomentPost> update(MomentPost post);

  Future<void> delete(String id);

  /// Posts for [chatId], including surviving chapter posts.
  Future<List<MomentPost>> listByChatId(String chatId);

  Future<List<MomentPost>> listAll();

  /// A page of posts in timeline order.
  Future<List<MomentPost>> listPage({int limit = 24, int offset = 0});

  Future<MomentPost?> findByChapterId(String chapterId);

  Future<MomentComment> addComment(MomentComment comment);

  Future<List<MomentComment>> listComments(String postId);

  /// Batch load for feed pages. Keys are post ids present in [postIds].
  Future<Map<String, List<MomentComment>>> listCommentsByPostIds(
    List<String> postIds,
  );

  Future<void> deleteComment(String commentId);

  Future<bool> toggleLike(String postId, String authorId, {DateTime? at});

  Future<int> likeCount(String postId);

  Future<Map<String, int>> likeCountsByPostIds(List<String> postIds);

  Future<bool> hasLiked(String postId, String authorId);

  /// Post ids in [postIds] that [authorId] has liked.
  Future<Set<String>> likedPostIdsAmong(
    List<String> postIds,
    String authorId,
  );
}
