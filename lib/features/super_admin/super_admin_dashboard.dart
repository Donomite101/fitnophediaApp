// lib/features/superadmin/super_admin_dashboard.dart
import 'package:fitnophedia/features/super_admin/superadmin_challenges_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// Core & Theme
import '../../core/app_theme.dart';
import '../../core/theme_provider.dart';
import '../../routes/app_routes.dart';

// Tabs
import 'dashboard_overview_tab.dart';
import 'pending_approvals_tab.dart';
import 'all_gyms_tab.dart';
import 'revenue_tab.dart';
import 'tickets_tab.dart';
import 'user_management_screen.dart';

class SuperAdminDashboard extends StatefulWidget {
  final String gymId;

  const SuperAdminDashboard({Key? key, this.gymId = ''}) : super(key: key);

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<_SidebarItem> _sidebarItems;

  @override
  void initState() {
    super.initState();
    _sidebarItems = [
      _SidebarItem(Icons.dashboard_outlined, 'Overview', const DashboardOverviewTab()),
      _SidebarItem(Icons.verified_user_outlined, 'Approvals', const PendingApprovalsTab()),
      _SidebarItem(Icons.business_outlined, 'Gyms', const AllGymsTab()),
      _SidebarItem(Icons.monetization_on_outlined, 'Revenue', const RevenueSubscriptionsTab()),
      _SidebarItem(Icons.support_agent_outlined, 'Support',
          const TicketChatScreen(currentUserId: '')),
      _SidebarItem(Icons.people_outline, 'Users', const UserManagementScreen()),
      _SidebarItem(
        Icons.flag,
        'Challenges',
        const SuperAdminChallengesScreen(),
      ),
    ];
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to log out?', style: GoogleFonts.poppins()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Logout', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.isDarkMode;
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF4F7FE),
      appBar: isDesktop
          ? null
          : AppBar(
        title: Text(
          _sidebarItems[_selectedIndex].label,
          style: GoogleFonts.poppins(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black87),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _logout(context),
          ),
        ],
      ),
      drawer: !isDesktop ? _buildSidebar(isDarkMode, false) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 280, child: _buildSidebar(isDarkMode, true)),
          Expanded(
            child: Column(
              children: [
                if (isDesktop) _buildDesktopHeader(isDarkMode),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: KeyedSubtree(
                        key: ValueKey(_selectedIndex),
                        child: _sidebarItems[_selectedIndex].widget ??
                            _buildPlaceholder(_sidebarItems[_selectedIndex].label),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDarkMode) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _sidebarItems[_selectedIndex].label,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : const Color(0xFF2B3674),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : const Color(0xFFF4F7FE),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.notifications_none,
                    color: isDarkMode ? Colors.white70 : Colors.grey),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () => _logout(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text('Logout',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDarkMode, bool isDesktop) {
    return Container(
      color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      child: Column(
        children: [
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.fitness_center, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'FITNOPHEDIA',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF2B3674),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          const Divider(height: 1, color: Colors.black12),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _sidebarItems.length,
              itemBuilder: (context, index) {
                final item = _sidebarItems[index];
                final selected = _selectedIndex == index;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.red.shade700 : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: Icon(
                      item.icon,
                      color: selected
                          ? Colors.white
                          : (isDarkMode ? Colors.white70 : const Color(0xFFA3AED0)),
                    ),
                    title: Text(
                      item.label,
                      style: GoogleFonts.poppins(
                        color: selected
                            ? Colors.white
                            : (isDarkMode ? Colors.white70 : const Color(0xFFA3AED0)),
                      ),
                    ),
                    onTap: () {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _selectedIndex = index);
                      });
                      if (!isDesktop) Navigator.pop(context);
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade900],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(Icons.verified_user, color: Colors.white, size: 32),
                  const SizedBox(height: 8),
                  Text('Super Admin',
                      style:
                      GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('Access Level: High',
                      style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder(String label) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '$label - Coming Soon',
            style: GoogleFonts.poppins(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem {
  final IconData icon;
  final String label;
  final Widget? widget;

  const _SidebarItem(this.icon, this.label, this.widget);
}
