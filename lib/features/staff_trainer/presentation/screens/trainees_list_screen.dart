import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import '../../../../core/app_theme.dart';
import 'trainee_detail_screen.dart';

class TraineesListScreen extends StatelessWidget {
  final String gymId;
  final String trainerId;

  const TraineesListScreen({Key? key, required this.gymId, required this.trainerId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('My Trainees', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('trainer_bookings')
            .where('trainerId', isEqualTo: trainerId)
            .where('gymId', isEqualTo: gymId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text('No trainees assigned or booked.', style: GoogleFonts.inter(color: Colors.grey)),
            );
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final bookingDoc = bookings[index];
              final bookingData = bookingDoc.data() as Map<String, dynamic>;
              final memberId = bookingData['memberId'];
              final status = bookingData['status'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
                builder: (context, memberSnapshot) {
                  if (!memberSnapshot.hasData) return const SizedBox.shrink();

                  final memberData = memberSnapshot.data!.data() as Map<String, dynamic>?;
                  if (memberData == null) return const SizedBox.shrink();

                  final memberName = memberData['name'] ?? 'Unknown Member';
                  final memberPhoto = memberData['photoUrl'];

                  return Card(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: CircleAvatar(
                        radius: 25,
                        backgroundColor: AppTheme.primaryGreen.withOpacity(0.1),
                        backgroundImage: memberPhoto != null ? NetworkImage(memberPhoto) : null,
                        child: memberPhoto == null ? const Icon(Iconsax.user, color: AppTheme.primaryGreen) : null,
                      ),
                      title: Text(
                        memberName,
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Status: ${status.toUpperCase()}', style: GoogleFonts.inter(fontSize: 12, color: status == 'pending' ? Colors.orange : AppTheme.primaryGreen)),
                        ],
                      ),
                      trailing: status == 'pending' 
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Iconsax.tick_circle, color: AppTheme.primaryGreen),
                                  onPressed: () => _updateBookingStatus(bookingDoc.id, 'active'),
                                ),
                                IconButton(
                                  icon: const Icon(Iconsax.close_circle, color: Colors.red),
                                  onPressed: () => _updateBookingStatus(bookingDoc.id, 'rejected'),
                                ),
                              ],
                            )
                          : const Icon(Iconsax.arrow_right_3),
                      onTap: status == 'active' ? () {
                        // Open Trainee Details screen where trainer tracks workouts, attendance, meal/diet
                        Navigator.push(context, MaterialPageRoute(builder: (context) => TraineeDetailScreen(
                          gymId: gymId,
                          trainerId: trainerId,
                          memberId: memberId,
                          memberName: memberName,
                          memberData: memberData,
                        )));
                      } : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    await FirebaseFirestore.instance.collection('trainer_bookings').doc(bookingId).update({'status': newStatus});
  }
}
