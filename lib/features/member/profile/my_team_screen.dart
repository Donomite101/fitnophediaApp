import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MyTeamScreen extends StatelessWidget {
  const MyTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final members = [
      {
        'name': 'Amanullah Pathan',
        'roll': '21CS45',
        'enrollment': 'ENR-2021-5543',
        'seat': 'Seat 12',
        'desc': 'Flutter developer & UI designer passionate about clean UX.',
      },
      {
        'name': 'Prathamesh Nigade',
        'roll': '21CS32',
        'enrollment': 'ENR-2021-5321',
        'seat': 'Seat 18',
        'desc': 'Focused and consistent learner with strong logical skills.',
      },
      {
        'name': 'Mahesh Barkade',
        'roll': '21CS67',
        'enrollment': 'ENR-2021-5789',
        'seat': 'Seat 05',
        'desc': 'Backend engineer who enjoys databases & clean architectures.',
      },
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark ? const Color(0xFF0B0B0E) : const Color(0xFFF1F5FF);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        centerTitle: true,
        title: Text("My Team", style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        itemCount: members.length,
        itemBuilder: (context, index) {
          final m = members[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: _teamCard(context, m, isDark),
          );
        },
      ),
    );
  }

  Widget _teamCard(BuildContext context, Map<String, String> m, bool isDark) {
    final cardColor = isDark ? const Color(0xFF121217) : Colors.white;
    final descText = isDark ? Colors.grey[300] : Colors.grey[600];
    final shadowColor = isDark ? Colors.black.withOpacity(0.6) : Colors.black.withOpacity(0.08);

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 18, offset: const Offset(0, 8)),
        ],
        border: isDark ? Border.all(color: Colors.white.withOpacity(0.04)) : null,
      ),
      child: Row(
        children: [
          // LEFT SIDE — AVATAR
          Container(
            width: 120,
            height: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Center(
              child: CircleAvatar(
                radius: 34,
                backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                child: Icon(Icons.person, size: 42, color: isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),

          // RIGHT SIDE — TEXT SECTION
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    m['name']!,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),

                  // Description
                  Expanded(
                    child: Text(
                      m['desc']!,
                      style: GoogleFonts.poppins(fontSize: 13, color: descText, height: 1.18),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Meta info row
                  Row(
                    children: [
                      _metaItem('Roll', m['roll']!, isDark),
                      const SizedBox(width: 8),
                      _metaItem('Enroll', m['enrollment']!, isDark),
                      const SizedBox(width: 8),
                      _metaItem('Seat', m['seat']!, isDark),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(String label, String value, bool isDark) {
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
