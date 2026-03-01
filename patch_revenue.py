import re

with open('lib/features/super_admin/revenue_tab.dart', 'r') as f:
    code = f.read()

# Make the Scaffold use dynamic bgColor
code = code.replace(
    'return Scaffold(\n      backgroundColor: Colors.grey[50],',
    '''final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2B3674);
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final bgColor = isDark ? const Color(0xFF121212) : Colors.grey[50];

    return Scaffold(
      backgroundColor: bgColor,'''
)

# Header
code = code.replace(
    '''Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),''',
    '''Widget _buildHeader(bool isDark, Color surfaceColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),'''
)
code = code.replace(
    '''              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),''',
    '''              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),'''
)
code = code.replace('_buildHeader()', '_buildHeader(isDark, surfaceColor, textColor)')

# Quick Stats
code = code.replace(
    '''Widget _buildRevenueStats() {''',
    '''Widget _buildRevenueStats(bool isDark, Color surfaceColor, Color textColor, Color subtitleColor) {'''
)
code = code.replace('_buildRevenueStats()', '_buildRevenueStats(isDark, surfaceColor, textColor, subtitleColor)')

code = code.replace(
    '''_buildRevenueStatCard(
              'Total Revenue',''',
    '''_buildRevenueStatCard(
              'Total Revenue', isDark, surfaceColor, textColor, subtitleColor,'''
)
code = code.replace(
    '''_buildRevenueStatCard(
              'Monthly Recurring',''',
    '''_buildRevenueStatCard(
              'Monthly Recurring', isDark, surfaceColor, textColor, subtitleColor,'''
)
code = code.replace(
    '''_buildRevenueStatCard(
              'Active Subs',''',
    '''_buildRevenueStatCard(
              'Active Subs', isDark, surfaceColor, textColor, subtitleColor,'''
)
code = code.replace(
    '''_buildRevenueStatCard(
              'Avg. Revenue/Sub',''',
    '''_buildRevenueStatCard(
              'Avg. Revenue/Sub', isDark, surfaceColor, textColor, subtitleColor,'''
)

code = code.replace(
    '''Widget _buildRevenueStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(''',
    '''Widget _buildRevenueStatCard(String title, bool isDark, Color surfaceColor, Color textColor, Color subtitleColor, String value, IconData icon, Color color, String subtitle) {
    return Card(
      elevation: 1,
      color: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding('''
)

code = code.replace(
    '''Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),''',
    '''Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: subtitleColor,
              ),
            ),'''
)

code = code.replace(
    '''Text(
              subtitle,
              style: const TextStyle(
                fontSize: 8,
                color: Colors.grey,
              ),
            ),''',
    '''Text(
              subtitle,
              style: TextStyle(
                fontSize: 8,
                color: subtitleColor,
              ),
            ),'''
)


with open('lib/features/super_admin/revenue_tab.dart', 'w') as f:
    f.write(code)

