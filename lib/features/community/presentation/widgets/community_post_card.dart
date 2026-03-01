import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:fitnophedia/features/community/presentation/screens/community_profile_screen.dart';
import 'package:fitnophedia/features/community/presentation/screens/comments_screen.dart';
import 'package:fitnophedia/core/app_theme.dart';
import 'package:intl/intl.dart';

class CommunityPostCard extends StatefulWidget {
  final PostModel post;
  final String userId;
  final VoidCallback? onDelete;

  const CommunityPostCard({
    Key? key,
    required this.post,
    required this.userId,
    this.onDelete,
  }) : super(key: key);

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  int _currentPage = 0;

  String _formatTimestamp(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final isMe = widget.post.userId == widget.userId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
            child: FutureBuilder<Map<String, dynamic>>(
              future: CommunityService.instance.getMemberDetails(widget.post.userId),
              builder: (context, userSnap) {
                final initialData = {
                  'username': widget.post.userName,
                  'profileImageUrl': widget.post.userProfileImage,
                };
                final userData = userSnap.data ?? initialData;
                final displayName = (userData['username'] ?? userData['firstName'] ?? widget.post.userName ?? 'Member').toString();
                final profileImg = (userData['profileImageUrl'] ?? userData['photoUrl'] ?? userData['imageUrl'] ?? userData['image'] ?? widget.post.userProfileImage ?? '').toString();
                
                return Row(
                  children: [
                    GestureDetector(
                      onTap: () => CommunityProfileScreen.navigate(context, widget.post.userId),
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppTheme.primaryGreen.withOpacity(0.5), 
                            width: 1.5
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 22,
                          backgroundColor: isDark ? Colors.white10 : Colors.black12,
                          backgroundImage: profileImg.isNotEmpty 
                            ? CachedNetworkImageProvider(profileImg)
                            : null,
                          child: profileImg.isEmpty ? const Icon(Iconsax.user, size: 22, color: Colors.white) : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                displayName.isEmpty ? 'Member' : displayName,
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              if (userData['isGymOwner'] == true) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.verified, size: 14, color: Colors.blue),
                              ],
                            ],
                          ),
                          if (widget.post.location != null && widget.post.location!.isNotEmpty)
                            Text(
                              widget.post.location!,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                _formatTimestamp(widget.post.createdAt),
                                style: GoogleFonts.inter(
                                  fontSize: 11, 
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Icon(Icons.circle, size: 2, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                              ),
                              if (userData['isGymOwner'] == true)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Gym Owner',
                                    style: GoogleFonts.inter(
                                      fontSize: 10, 
                                      color: AppTheme.primaryGreen.withOpacity(0.9),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              else
                                FutureBuilder<String>(
                                  future: CommunityService.instance.getGymName(widget.post.gymId),
                                  builder: (context, snap) => Text(
                                    snap.data ?? 'Member',
                                    style: GoogleFonts.inter(
                                      fontSize: 10, 
                                      color: AppTheme.primaryGreen.withOpacity(0.7),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (widget.post.userId == FirebaseAuth.instance.currentUser?.uid)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_horiz, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showEditDialog(context);
                          } else if (value == 'delete') {
                            if (widget.onDelete != null) widget.onDelete!();
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Iconsax.edit_2, size: 18, color: theme.colorScheme.onSurface),
                                const SizedBox(width: 8),
                                const Text('Edit Post'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Iconsax.trash, size: 18, color: Colors.redAccent),
                                const SizedBox(width: 8),
                                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
          ),
          
          // ── Caption (Simple - for media posts) ────────────────
          if (widget.post.caption.isNotEmpty && widget.post.mediaUrls.any((url) => url.isNotEmpty))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.post.caption,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  height: 1.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

          if (widget.post.mediaUrls.isNotEmpty && widget.post.mediaUrls.any((url) => url.isNotEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: GestureDetector(
                onDoubleTap: () => CommunityService.instance.toggleLike(widget.post.id, widget.userId),
                onTap: () {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) CommunityService.instance.incrementPostViews(widget.post.id, uid);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 350,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                      border: Border.all(color: Colors.white.withOpacity(0.1), width: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: widget.post.mediaUrls.where((url) => url.isNotEmpty).length > 1
                      ? Stack(
                          children: [
                            PageView.builder(
                              itemCount: widget.post.mediaUrls.where((url) => url.isNotEmpty).length,
                              physics: const BouncingScrollPhysics(),
                              onPageChanged: (idx) => setState(() => _currentPage = idx),
                              itemBuilder: (context, idx) {
                                final validUrls = widget.post.mediaUrls.where((url) => url.isNotEmpty).toList();
                                return CachedNetworkImage(
                                  imageUrl: validUrls[idx],
                                  width: double.infinity,
                                  height: 350,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  errorWidget: (context, url, error) => _buildImageErrorPlaceholder(isDark),
                                );
                              },
                            ),
                            Positioned(
                              bottom: 12,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(widget.post.mediaUrls.where((url) => url.isNotEmpty).length, (idx) {
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    width: _currentPage == idx ? 12 : 6,
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(horizontal: 2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(3),
                                      color: _currentPage == idx ? AppTheme.primaryGreen : Colors.white.withOpacity(0.5),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "${_currentPage + 1}/${widget.post.mediaUrls.where((url) => url.isNotEmpty).length}",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : CachedNetworkImage(
                          imageUrl: widget.post.mediaUrls.firstWhere((url) => url.isNotEmpty),
                          width: double.infinity,
                          height: 350,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (context, url, error) => _buildImageErrorPlaceholder(isDark),
                        ),
                  ),
                ),
              ),
            )
          else
            // PREMIUM TEXT CARD (for text-only posts)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [Colors.white.withOpacity(0.04), Colors.white.withOpacity(0.01)]
                      : [AppTheme.primaryGreen.withOpacity(0.08), Colors.white],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.03) : AppTheme.primaryGreen.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Iconsax.document_text,
                      size: 32,
                      color: isDark ? Colors.white10 : AppTheme.primaryGreen.withOpacity(0.2),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.post.caption,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "PERSONAL UPDATE",
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white24 : AppTheme.primaryGreen.withOpacity(0.4),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Liked By Section ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.post.id)
                  .collection('likes')
                  .limit(2)
                  .snapshots(),
              builder: (context, likeSnap) {
                if (widget.post.likesCount == 0) return const SizedBox.shrink();
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: widget.post.likesCount > 1 ? 38 : 22,
                        height: 22,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 11,
                              backgroundColor: Colors.grey[800],
                              child: const Icon(Icons.person, size: 12, color: Colors.white),
                            ),
                            if (widget.post.likesCount > 1)
                              Positioned(
                                left: 14,
                                child: CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.grey[700],
                                  child: const Icon(Icons.person, size: 12, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Liked by ${widget.post.likesCount < 0 ? 0 : widget.post.likesCount} members',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                );
              }
            ),
          ),
          
          // ── Actions Bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Like Button
                    StreamBuilder<DocumentSnapshot>(
                      stream: CommunityService.instance.getLikeStatus(widget.post.id, widget.userId),
                      builder: (context, snap) {
                        final isLiked = snap.hasData && snap.data!.exists;
                        return Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                isLiked ? Iconsax.heart5 : Iconsax.heart,
                                color: isLiked ? Colors.red : theme.colorScheme.onSurface,
                                size: 24,
                              ),
                              onPressed: () => CommunityService.instance.toggleLike(widget.post.id, widget.userId),
                            ),
                          ],
                        );
                      }
                    ),
                    const SizedBox(width: 4),
                    // Comment Button
                    IconButton(
                      icon: Icon(Iconsax.message, color: theme.colorScheme.onSurface, size: 24),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CommentsScreen(
                            postId: widget.post.id,
                            userId: widget.userId,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Send Button
                    IconButton(
                      icon: Icon(Iconsax.send_1, color: theme.colorScheme.onSurface, size: 24),
                      onPressed: () {},
                    ),
                    const SizedBox(width: 4),
                    // Save Button
                    StreamBuilder<bool>(
                      stream: CommunityService.instance.isSaved(widget.userId, widget.post.id),
                      builder: (context, snap) {
                        final isSaved = snap.data ?? false;
                        return IconButton(
                          icon: Icon(
                            isSaved ? Iconsax.archive_tick : Iconsax.archive_add,
                            color: isSaved ? AppTheme.primaryGreen : theme.colorScheme.onSurface,
                            size: 24,
                          ),
                          onPressed: () => CommunityService.instance.toggleSave(widget.userId, widget.post.id),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageErrorPlaceholder(bool isDark) {
    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.image, size: 40, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 12),
          Text(
            "Image not available",
            style: GoogleFonts.inter(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: widget.post.caption);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Caption',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: GoogleFonts.inter(fontSize: 15),
          decoration: InputDecoration(
            hintText: 'What\'s on your mind?',
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.02),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim() != widget.post.caption) {
                await CommunityService.instance.updatePost(widget.post.id, {
                  'caption': controller.text.trim(),
                });
                if (mounted) setState(() {}); // Refresh local UI
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
