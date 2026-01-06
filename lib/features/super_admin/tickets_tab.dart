// lib/screens/ticket_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Optional Firestore usage
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TicketChatScreen extends StatefulWidget {
  /// If useFirestore == true you MUST provide gymId & chatId and have Firebase initialized.
  final bool useFirestore;
  final String? gymId;
  final String? chatId;
  final String title;
  final String subtitle;
  final String avatarInitial;
  final String currentUserId;
  final String currentUserRole; // 'member' | 'owner' | 'admin'
  const TicketChatScreen({
    Key? key,
    this.useFirestore = false,
    this.gymId,
    this.chatId,
    this.title = 'SDF Support',
    this.subtitle = '',
    this.avatarInitial = 'S',
    required this.currentUserId,
    this.currentUserRole = 'owner',
  }) : super(key: key);

  @override
  _TicketChatScreenState createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _sending = false;

  // Mock messages when useFirestore == false
  List<_ChatMessage> _mockMessages = [
    _ChatMessage(
      id: '1',
      senderId: 'owner1',
      senderRole: 'owner',
      text:
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam...',
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
    ),
    _ChatMessage(
      id: '2',
      senderId: 'member1',
      senderRole: 'member',
      text:
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
      createdAt: DateTime.now().subtract(const Duration(hours: 18)),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Sends message: writes to Firestore or updates mock list
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _sending = true;
    });

    final now = DateTime.now();

    if (widget.useFirestore) {
      // Firestore mode: add message to messages subcollection and update chat lastMessage
      try {
        final gymId = widget.gymId!;
        final chatId = widget.chatId!;
        final user = FirebaseAuth.instance.currentUser;
        final uid = user?.uid ?? widget.currentUserId;

        final msgRef = FirebaseFirestore.instance
            .collection('gyms')
            .doc(gymId)
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .doc();

        await msgRef.set({
          'senderId': uid,
          'senderRole': widget.currentUserRole,
          'text': text,
          'type': 'text',
          'createdAt': FieldValue.serverTimestamp(),
        });

        // update parent chat doc with lastMessage + lastUpdated
        final chatRef = FirebaseFirestore.instance.collection('gyms').doc(gymId).collection('chats').doc(chatId);
        await chatRef.set({
          'lastMessage': text,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        _controller.clear();
        _scrollToBottom();
      } catch (e) {
        debugPrint('Send message error: $e');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } else {
      // Mock mode: add to local list
      setState(() {
        _mockMessages.add(_ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          senderId: widget.currentUserId,
          senderRole: widget.currentUserRole,
          text: text,
          createdAt: now,
        ));
        _controller.clear();
      });
      // small delay then scroll
      await Future.delayed(const Duration(milliseconds: 100));
      _scrollToBottom();
    }

    setState(() {
      _sending = false;
    });
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
      title: Row(
        children: [
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blue.shade50,
            child: Text(widget.avatarInitial, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                if (widget.subtitle.isNotEmpty)
                  Text(widget.subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () {
            // Ticket info pressed
            showModalBottomSheet(
              context: context,
              builder: (_) => _TicketInfoSheet(title: widget.title),
            );
          },
          icon: const Icon(Icons.info_outline, color: Colors.grey),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessageList() {
    if (widget.useFirestore) {
      final gymId = widget.gymId!;
      final chatId = widget.chatId!;
      final messagesStream = FirebaseFirestore.instance
          .collection('gyms')
          .doc(gymId)
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots();

      return StreamBuilder<QuerySnapshot>(
        stream: messagesStream,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          final messages = docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final ts = data['createdAt'] as Timestamp?;
            return _ChatMessage(
              id: d.id,
              senderId: data['senderId'] ?? '',
              senderRole: data['senderRole'] ?? 'member',
              text: data['text'] ?? '',
              createdAt: ts?.toDate() ?? DateTime.now(),
            );
          }).toList();

          return _messagesListView(messages);
        },
      );
    } else {
      return _messagesListView(_mockMessages);
    }
  }

  Widget _messagesListView(List<_ChatMessage> messages) {
    // Build grouped by date optionally
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      itemCount: messages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Top spacing or optional header
          return const SizedBox(height: 6);
        }
        final msg = messages[index - 1];
        final isMine = msg.senderId == widget.currentUserId;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
              child: _MessageBubble(
                text: msg.text,
                isMine: isMine,
                time: DateFormat('yyyy/MM/dd').format(msg.createdAt),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _buildInputBar() {
    final primary = Theme.of(context).colorScheme.primary;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          border: Border(top: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                // attach file
              },
              icon: const Icon(Icons.attach_file_outlined),
              color: Colors.grey[700],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.03), blurRadius: 6)],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Type a Message...',
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 4,
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // emoji picker
                      },
                      icon: const Icon(Icons.emoji_emotions_outlined),
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _sending ? null : _sendMessage,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _sending ? Colors.grey : Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // base scaffold matching screenshot
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: PreferredSize(preferredSize: const Size.fromHeight(72), child: _buildAppBar()),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildInputBar(),
        ],
      ),
    );
  }
}

/// Simple ticket info bottom sheet used by app bar button
class _TicketInfoSheet extends StatelessWidget {
  final String title;
  const _TicketInfoSheet({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      height: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ticket Info', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Subject: $title'),
          const SizedBox(height: 10),
          Text('Status: Open', style: TextStyle(color: Colors.green[700])),
          const SizedBox(height: 8),
          Text('Created: ${DateFormat.yMMMMd().format(DateTime.now().subtract(const Duration(days: 4)))}'),
          const SizedBox(height: 12),
          Text('Notes:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Member raised a support request regarding billing and access.'),
        ],
      ),
    );
  }
}

/// Message bubble widget matching screenshot style
class _MessageBubble extends StatelessWidget {
  final String text;
  final bool isMine;
  final String time;
  const _MessageBubble({Key? key, required this.text, this.isMine = false, required this.time}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? Colors.blueAccent : Colors.grey.shade200;
    final fg = isMine ? Colors.white : Colors.black87;
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isMine ? 12 : 18),
      topRight: Radius.circular(isMine ? 18 : 12),
      bottomLeft: const Radius.circular(18),
      bottomRight: const Radius.circular(18),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: Colors.black12.withOpacity(0.02), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, style: TextStyle(color: fg)),
            const SizedBox(height: 8),
            Text(time, style: TextStyle(color: fg.withOpacity(0.75), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Simple in-memory model
class _ChatMessage {
  final String id;
  final String senderId;
  final String senderRole;
  final String text;
  final DateTime createdAt;
  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.text,
    required this.createdAt,
  });
}
