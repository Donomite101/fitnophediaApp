import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:intl/intl.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;

  const CommentsScreen({Key? key, required this.postId}) : super(key: key);

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isPosting = false;

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isPosting = true);

    try {
      // We need user details for the comment. Usually these come from a UserProvider or similar.
      // For now, let's fetch them from the current member doc.
      final memberDoc = await FirebaseFirestore.instance.collection('members').doc(user.uid).get();
      final data = memberDoc.data() ?? {};
      final userName = data['firstName'] ?? 'Member';
      final profileUrl = data['profileImageUrl'] ?? '';

      await CommunityService.instance.addComment(
        widget.postId,
        userId: user.uid,
        userName: userName,
        userProfileImage: profileUrl,
        text: text,
      );

      _commentController.clear();
      FocusScope.of(context).unfocus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error posting comment: $e")),
      );
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comments', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: CommunityService.instance.getComments(widget.postId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.green));
                }

                final comments = snapshot.data?.docs ?? [];
                
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).snapshots(),
                  builder: (context, postSnapshot) {
                    if (!postSnapshot.hasData) return const SizedBox();
                    final postData = postSnapshot.data!.data() as Map<String, dynamic>?;
                    if (postData == null) return const Center(child: Text("Post not found"));
                    
                    final post = PostModel.fromFirestore(postSnapshot.data!);
                    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 0),
                      itemCount: comments.length + 1, // +1 for the post header
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          // Post Header
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Post Media
                              AspectRatio(
                                aspectRatio: 1,
                                child: CachedNetworkImage(
                                  imageUrl: post.mediaUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(color: Colors.grey[900]),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                ),
                              ),
                              // Actions & Likes
                              Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('posts')
                                              .doc(post.id)
                                              .collection('likes')
                                              .doc(currentUserId)
                                              .snapshots(),
                                          builder: (context, likeSnap) {
                                            final isLiked = likeSnap.hasData && likeSnap.data!.exists;
                                            return IconButton(
                                              icon: Icon(
                                                isLiked ? Iconsax.heart5 : Iconsax.heart,
                                                color: isLiked ? Colors.red : null,
                                              ),
                                              onPressed: () => CommunityService.instance.toggleLike(post.id, currentUserId),
                                            );
                                          },
                                        ),
                                        IconButton(
                                          icon: const Icon(Iconsax.message), 
                                          onPressed: () {}, // Already on comments screen
                                        ),
                                        const Spacer(),
                                        StreamBuilder<DocumentSnapshot>(
                                          stream: FirebaseFirestore.instance.collection('posts').doc(post.id).snapshots(),
                                          builder: (context, postSnap) {
                                            final Map<String, dynamic>? data = postSnap.data?.data() as Map<String, dynamic>?;
                                            final count = data?['likesCount'] ?? post.likesCount;
                                            return Text(
                                              '$count likes',
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                            );
                                          }
                                        ),
                                      ],
                                    ),
                                    if (post.caption.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                                            children: [
                                              TextSpan(
                                                text: '${post.userName} ',
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              TextSpan(text: post.caption),
                                            ],
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    const Divider(),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                      child: Text(
                                        'COMMENTS',
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Colors.grey,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        // Comment Item
                        final data = comments[index - 1].data() as Map<String, dynamic>;
                        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                        
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundImage: (data['userProfileImage'] ?? '').isNotEmpty
                                  ? CachedNetworkImageProvider(data['userProfileImage'])
                                  : null,
                                child: (data['userProfileImage'] ?? '').isEmpty ? const Icon(Icons.person, size: 20) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          data['userName'] ?? 'Member',
                                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat.jm().format(createdAt),
                                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      data['text'] ?? '',
                                      style: GoogleFonts.poppins(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                );
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              top: 12,
              left: 16,
              right: 16,
            ),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      fillColor: Colors.grey.withOpacity(0.1),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 12),
                if (_isPosting)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green))
                else
                  IconButton(
                    onPressed: _postComment,
                    icon: const Icon(Icons.send, color: Colors.green),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
