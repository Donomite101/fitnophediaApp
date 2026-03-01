import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:iconsax/iconsax.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fitnophedia/core/utils/class_image_helper.dart';
import '../../../core/app_theme.dart';

class MemberClassDetailsScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final Map<String, dynamic> classData;

  const MemberClassDetailsScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
    required this.classData,
  }) : super(key: key);

  @override
  State<MemberClassDetailsScreen> createState() => _MemberClassDetailsScreenState();
}

class _MemberClassDetailsScreenState extends State<MemberClassDetailsScreen> {
  bool _isBooking = false;
  bool _isAlreadyBooked = false;

  @override
  void initState() {
    super.initState();
    _checkBookingStatus();
  }

  Future<void> _checkBookingStatus() async {
    final bookingDoc = await FirebaseFirestore.instance
        .collection('gyms')
        .doc(widget.gymId)
        .collection('classes')
        .doc(widget.classData['id'])
        .collection('bookings')
        .doc(widget.memberId)
        .get();

    if (mounted) {
      setState(() {
        _isAlreadyBooked = bookingDoc.exists;
      });
    }
  }

  Future<void> _bookClass() async {
    if (_isAlreadyBooked) return;

    setState(() => _isBooking = true);

    try {
      final classRef = FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('classes')
          .doc(widget.classData['id']);

      // ── Fetch member name + photo before the transaction ──
      String memberName = 'Member';
      String? memberPhoto;
      try {
        final memberDoc = await FirebaseFirestore.instance
            .collection('gyms')
            .doc(widget.gymId)
            .collection('members')
            .doc(widget.memberId)
            .get();
        if (memberDoc.exists) {
          memberName = memberDoc.data()?['name'] ?? memberDoc.data()?['displayName'] ?? 'Member';
          memberPhoto = memberDoc.data()?['profileImage'] ?? memberDoc.data()?['photoUrl'];
        } else {
          // fallback to users collection
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.memberId)
              .get();
          memberName = userDoc.data()?['name'] ?? userDoc.data()?['displayName'] ?? 'Member';
          memberPhoto = userDoc.data()?['profileImage'] ?? userDoc.data()?['photoUrl'];
        }
      } catch (_) {}

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final classSnap = await transaction.get(classRef);
        if (!classSnap.exists) return;

        final participants = classSnap.data()?['participants'] as int? ?? 0;
        final capacity = classSnap.data()?['capacity'] as int? ?? 20;

        if (participants >= capacity) {
          throw Exception("Class is full");
        }

        // Add booking with member info
        final bookingRef = classRef.collection('bookings').doc(widget.memberId);
        transaction.set(bookingRef, {
          'memberId': widget.memberId,
          'memberName': memberName,
          if (memberPhoto != null) 'memberPhoto': memberPhoto,
          'bookedAt': FieldValue.serverTimestamp(),
          'status': 'confirmed',
        });

        // Increment participants
        transaction.update(classRef, {
          'participants': FieldValue.increment(1),
        });

        // Add notification for gym owner
        final notificationRef = FirebaseFirestore.instance.collection('notifications').doc();
        transaction.set(notificationRef, {
          'gymId': widget.gymId,
          'type': 'class_booking',
          'title': 'New Class Booking! 🏋️‍♂️',
          'message': '$memberName has booked the ${widget.classData['className'] ?? 'Fitness'} class.',
          'memberId': widget.memberId,
          'memberName': memberName,
          'classId': widget.classData['id'],
          'className': widget.classData['className'],
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (mounted) {
        setState(() {
          _isAlreadyBooked = true;
          _isBooking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Class booked successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _cancelBooking() async {
    setState(() => _isBooking = true);

    try {
      final classRef = FirebaseFirestore.instance
          .collection('gyms')
          .doc(widget.gymId)
          .collection('classes')
          .doc(widget.classData['id']);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final bookingRef = classRef.collection('bookings').doc(widget.memberId);
        final bookingSnap = await transaction.get(bookingRef);

        if (!bookingSnap.exists) return;

        // Delete booking
        transaction.delete(bookingRef);

        // Decrement participants
        transaction.update(classRef, {
          'participants': FieldValue.increment(-1),
        });
      });

      if (mounted) {
        setState(() {
          _isAlreadyBooked = false;
          _isBooking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final data = widget.classData;
    final category = data['category'] ?? 'general';
    final imageUrl = data['imageUrl'] ?? ClassImageHelper.getCategoryImage(category);
    final color = _getColorFromHex(data['color'] ?? '#00E676');

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: CustomScrollView(
        slivers: [
          // Header Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? Colors.black : Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  ClassImageHelper.isAsset(imageUrl)
                      ? Image.asset(imageUrl, fit: BoxFit.cover)
                      : CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          isDark ? Colors.black : Colors.black54,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and Category
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data['className'] ?? 'Fitness Class',
                          style: GoogleFonts.outfit(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          category.toUpperCase(),
                          style: GoogleFonts.outfit(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Instructor
                  Row(
                    children: [
                      const Icon(Iconsax.user, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        'with ${data['trainer'] ?? 'Instructor'}',
                        style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info Grid
                  Row(
                    children: [
                      _buildInfoItem(Iconsax.clock, 'Time', data['time'] ?? 'TBD', isDark),
                      _buildInfoItem(Iconsax.calendar, 'Days', (data['days'] as List?)?.join(', ') ?? 'Varies', isDark),
                      _buildInfoItem(Iconsax.people, 'Capacity', '${data['participants'] ?? 0}/${data['capacity'] ?? 20}', isDark),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Description
                  Text(
                    'About Class',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    data['description'] ?? 'No description available for this class.',
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 100), // Space for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isBooking 
                  ? null 
                  : (_isAlreadyBooked ? _cancelBooking : _bookClass),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isAlreadyBooked ? Colors.redAccent : AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isBooking
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      _isAlreadyBooked ? 'Cancel Booking' : 'Book Now',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryGreen, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) hexColor = "FF$hexColor";
    if (hexColor.length == 8) {
      return Color(int.parse("0x$hexColor"));
    }
    return AppTheme.primaryGreen;
  }
}
