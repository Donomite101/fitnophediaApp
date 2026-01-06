// lib/features/member/profile/support_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/app_theme.dart';

class SupportScreen extends StatefulWidget {
  final String? gymId;
  final String? memberId;

  const SupportScreen({Key? key, this.gymId, this.memberId}) : super(key: key);

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtl = TextEditingController();
  final TextEditingController _emailCtl = TextEditingController();
  final TextEditingController _messageCtl = TextEditingController();
  bool _isSending = false;
  bool _showForm = false;

  final List<Map<String, String>> _faqs = [
    {
      'q': 'How do I change my subscription?',
      'a': 'Open Subscription from your profile and follow the renewal/activation flow.'
    },
    {
      'q': 'How do I reset my password?',
      'a': 'Use the "Forgot password" link on the login screen to reset via email.'
    },
    {
      'q': 'How long does approval take for cash payments?',
      'a': 'Approval timing depends on the gym owner — typically within 24–72 hours.'
    },
  ];

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _messageCtl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSending = true);

    try {
      final doc = {
        'name': _nameCtl.text.trim(),
        'email': _emailCtl.text.trim(),
        'message': _messageCtl.text.trim(),
        'gymId': widget.gymId,
        'memberId': widget.memberId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'open',
      };

      await FirebaseFirestore.instance.collection('support_messages').add(doc);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message sent — our team will get back to you.'), backgroundColor: AppTheme.primaryGreen),
      );

      _formKey.currentState!.reset();
      _nameCtl.clear();
      _emailCtl.clear();
      _messageCtl.clear();

      // collapse form after successful send
      setState(() => _showForm = false);
    } catch (e) {
      debugPrint('Support message error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _toggleForm() {
    setState(() => _showForm = !_showForm);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final muted = isDark ? Colors.grey[400] : Colors.grey[700];

    return Scaffold(
      appBar: AppBar(
        title: Text('Support', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: AppTheme.primaryGreen,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _toggleForm,
        backgroundColor: AppTheme.primaryGreen,
        label: Text(_showForm ? 'Close' : 'Send Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        icon: Icon(_showForm ? Icons.close : Icons.message),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _showForm ? _buildMessageForm(context) : _buildHelpView(context, surface, onSurface, muted),
        ),
      ),
    );
  }

  // ---------- Illustration card (uses assets/Mention-bro.svg) ----------
  Widget _illustrationCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0E) : Colors.white;
    final muted = isDark ? Colors.grey[300] : Colors.grey[700];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent),
      ),
      child: Column(
        children: [
          // Illustration (SVG)
          SizedBox(
            height: 160,
            child: SvgPicture.asset(
              'assets/Mention-bro.svg',
              fit: BoxFit.contain,
              // If you want to tint the svg, you can pass color: ...
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "How can we help you?",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            "Browse FAQs or send us a message — we'll reply within 24–48 hours.",
            style: GoogleFonts.poppins(fontSize: 13, color: muted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpView(BuildContext context, Color surface, Color onSurface, Color? muted) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 8),
        _illustrationCard(context),
        const SizedBox(height: 18),
        Text('FAQs', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ..._faqs.map((f) => _faqTile(f['q']!, f['a']!, muted)).toList(),
        const SizedBox(height: 24),
        Center(child: Text('Still need help? Tap the button below to send us a message.', style: GoogleFonts.poppins(color: muted))),
        const SizedBox(height: 28),
      ],
    );
  }

  Widget _faqTile(String q, String a, Color? muted) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tileBg = isDark ? const Color(0xFF0B0B0E) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Material(
        color: tileBg,
        borderRadius: BorderRadius.circular(12),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          collapsedIconColor: muted,
          iconColor: AppTheme.primaryGreen,
          title: Text(q, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(a, style: GoogleFonts.poppins(color: muted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageForm(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0B0E) : Colors.white;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent),
              boxShadow: [BoxShadow(color: isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 8))],
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Send us a message', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameCtl,
                    decoration: InputDecoration(labelText: 'Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtl,
                    decoration: InputDecoration(labelText: 'Email', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      final s = (v ?? '').trim();
                      if (s.isEmpty) return 'Please enter email';
                      if (!s.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _messageCtl,
                    decoration: InputDecoration(labelText: 'Message', border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    maxLines: 6,
                    validator: (v) => (v ?? '').trim().length < 6 ? 'Please describe the issue' : null,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSending ? null : _sendMessage,
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen, minimumSize: const Size.fromHeight(48)),
                          child: _isSending
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : Text('Send Message', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _showForm = false;
                          });
                        },
                        child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Center(child: Text('Thank you — we are here to help.', style: GoogleFonts.poppins(color: isDark ? Colors.grey[400] : Colors.grey[700]))),
        ],
      ),
    );
  }
}
