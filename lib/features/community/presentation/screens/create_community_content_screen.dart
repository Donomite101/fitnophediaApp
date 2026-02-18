import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';
import 'package:fitnophedia/features/community/domain/models/community_models.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateCommunityContentScreen extends StatefulWidget {
  final bool isStory;
  final String? gymId;

  const CreateCommunityContentScreen({Key? key, this.isStory = false, this.gymId}) : super(key: key);

  @override
  State<CreateCommunityContentScreen> createState() => _CreateCommunityContentScreenState();
}

class _CreateCommunityContentScreenState extends State<CreateCommunityContentScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  
  File? _selectedFile;
  bool _isUploading = false;
  bool _hasAttemptedPick = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasAttemptedPick) {
        _pickMedia();
      }
    });
  }

  Future<void> _pickMedia() async {
    _hasAttemptedPick = true;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final XFile? picked = await _imagePicker.pickImage(source: source);
    if (picked != null) {
      if (mounted) {
        setState(() {
          _selectedFile = File(picked.path);
        });
      }
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _uploadContent() async {
    if (_selectedFile == null) return;

    setState(() => _isUploading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch real member data to get the correct name/image
    final userData = await CommunityService.instance.getMemberDetails(user.uid);
    final userName = userData['username'] ?? userData['firstName'] ?? user.displayName ?? 'Member';
    final userProfileImage = userData['profileImageUrl'] ?? user.photoURL ?? '';

    final mediaUrl = await CommunityService.instance.uploadMedia(_selectedFile!, resourceType: 'image');

    if (mediaUrl != null) {
      if (widget.isStory) {
        final story = StoryModel(
          id: '',
          userId: user.uid,
          userName: userName,
          userProfileImage: userProfileImage,
          mediaUrl: mediaUrl,
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          createdAt: DateTime.now(),
        );
        await CommunityService.instance.createStory(story);
      } else {
        final post = PostModel(
          id: '',
          userId: user.uid,
          userName: userName,
          userProfileImage: userProfileImage,
          mediaUrl: mediaUrl,
          mediaType: 'image',
          caption: _captionController.text,
          likesCount: 0,
          gymId: widget.gymId,
          createdAt: DateTime.now(),
        );
        await CommunityService.instance.createPost(post);
      }
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          widget.isStory ? 'NEW STORY' : 'NEW POST', 
          style: GoogleFonts.bebasNeue(letterSpacing: 1),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedFile != null && !_isUploading)
            TextButton(
              onPressed: _uploadContent,
              child: const Text(
                'SHARE',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
              ),
            ),
        ],
      ),
      body: _isUploading 
        ? const Center(child: CircularProgressIndicator(color: Colors.green))
        : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_selectedFile == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 300,
              width: double.infinity,
              child: Image.file(_selectedFile!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          if (!widget.isStory)
            TextField(
              controller: _captionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Write a caption...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white10,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
