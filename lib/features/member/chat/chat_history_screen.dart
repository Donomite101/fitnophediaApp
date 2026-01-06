import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'ChatScreen.dart'; // Import ChatScreen to navigate
import 'widgets/plan_card.dart';

class ChatHistoryScreen extends StatefulWidget {
  const ChatHistoryScreen({Key? key}) : super(key: key);

  @override
  State<ChatHistoryScreen> createState() => _ChatHistoryScreenState();
}

class _ChatHistoryScreenState extends State<ChatHistoryScreen> {
  String? _gymId;

  @override
  void initState() {
    super.initState();
    _fetchGymId();
  }

  Future<void> _fetchGymId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted) {
        setState(() {
          _gymId = doc.data()?['gymId'];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: Text(
            "History",
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
          bottom: TabBar(
            labelColor: const Color(0xFF00E676),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF00E676),
            labelStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Chats"),
              Tab(text: "Saved Plans"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: "Clear All History",
              onPressed: () => _confirmClearHistory(context),
            ),
          ],
        ),
        body: user == null
            ? const Center(child: Text("Please login to view history"))
            : TabBarView(
                children: [
                  _buildSessionsTab(user, isDark),
                  _buildSavedPlansTab(user, isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildSessionsTab(User user, bool isDark) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_sessions')
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No chats yet");
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['lastUpdated'] as Timestamp?;
            final timeStr = timestamp != null
                ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                : '';

            return Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              elevation: 2,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                title: Text(
                  data['title'] ?? 'New Chat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    data['preview'] ?? 'No preview',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Outfit',
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF00E676)),
                  ],
                ),
                onTap: () {
                  // Navigate to ChatScreen with this session ID
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(sessionId: doc.id),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSavedPlansTab(User user, bool isDark) {
    if (_gymId == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
    }

    // Combine streams or just show workout plans for now
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('gyms')
          .doc(_gymId)
          .collection('members')
          .doc(user.uid)
          .collection('workout_plans')
          .orderBy('savedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState("No saved plans");
        }

        final docs = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final plan = data['plan'] as Map<String, dynamic>?;
            final timestamp = data['savedAt'] as Timestamp?;
            final timeStr = timestamp != null
                ? DateFormat('MMM d, y').format(timestamp.toDate())
                : '';

            if (plan == null) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Text(
                    "Saved on $timeStr",
                    style: TextStyle(fontSize: 12, color: Colors.grey, fontFamily: 'Outfit'),
                  ),
                ),
                PlanCard(
                  workoutPlan: plan, // Assuming it's a workout plan
                  dietPlan: null,
                  onSave: () {}, 
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearHistory(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear All History?"),
        content: const Text("This will delete all chat sessions. Saved plans will remain."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final collection = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('chat_sessions');
        
        final snapshot = await collection.get();
        final batch = FirebaseFirestore.instance.batch();
        
        for (var doc in snapshot.docs) {
          batch.delete(doc.reference);
          // Note: Subcollections (messages) are not automatically deleted in Firestore!
          // But for UI purposes, the session is gone. 
          // A Cloud Function is usually best for recursive delete.
        }
        
        await batch.commit();
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Chat history cleared")),
          );
        }
      } catch (e) {
        debugPrint("Error clearing history: $e");
      }
    }
  }
}
