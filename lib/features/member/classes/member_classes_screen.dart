import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../dashboard/member_class_card.dart';
import 'member_class_details_screen.dart';

class MemberClassesScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const MemberClassesScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<MemberClassesScreen> createState() => _MemberClassesScreenState();
}

class _MemberClassesScreenState extends State<MemberClassesScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("All Classes", style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gyms')
            .doc(widget.gymId)
            .collection('classes')
            .where('isActive', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(
                "No classes available",
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final classData = docs[index].data() as Map<String, dynamic>;
              classData['id'] = docs[index].id;
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: MemberClassCard(
                  classData: classData,
                  isDarkMode: isDark,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MemberClassDetailsScreen(
                          gymId: widget.gymId,
                          memberId: widget.memberId,
                          classData: classData,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
