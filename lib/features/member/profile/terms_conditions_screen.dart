import 'package:flutter/material.dart';

class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  final List<ExpandableCardData> _termsCards = [
    ExpandableCardData(
      title: '1. Acceptance',
      content: 'By using Fitnophedia, you agree to our terms. Discontinue use if you do not agree.',
    ),
    ExpandableCardData(
      title: '2. Eligibility',
      content: 'You must be 16+ years old and provide accurate information.',
    ),
    ExpandableCardData(
      title: '3. Account Security',
      content: 'Keep your login credentials secure. We are not responsible for compromised accounts.',
    ),
    ExpandableCardData(
      title: '4. Payments',
      content: 'Gym subscriptions are non-refundable. Members pay gyms directly unless specified otherwise.',
    ),
    ExpandableCardData(
      title: '5. Health Disclaimer',
      content: 'Fitnophedia provides fitness guidance, not medical advice. Consult a doctor before starting any program.',
    ),
    ExpandableCardData(
      title: '6. Data Privacy',
      content: 'We collect fitness data to personalize your experience. Data is protected under DPDP Act, India.',
    ),
    ExpandableCardData(
      title: '7. Content Rules',
      content: 'Do not upload illegal, harmful, or copyrighted content. Violations may lead to account termination.',
    ),
    ExpandableCardData(
      title: '8. Service Changes',
      content: 'We may update terms anytime. Continued use means acceptance of changes.',
    ),
    ExpandableCardData(
      title: '9. Contact',
      content: 'Email: fitnophedia@gmail.com\nPhone: +91-9854638786',
    ),
  ];

  final List<ExpandableCardData> _privacyCards = [
    ExpandableCardData(
      title: '1. Data Collected',
      content: 'We collect account info, fitness data, subscription details, and device information.',
    ),
    ExpandableCardData(
      title: '2. Data Usage',
      content: 'Data is used for fitness plans, communication, analytics, and service improvement.',
    ),
    ExpandableCardData(
      title: '3. Data Sharing',
      content: 'Shared only with your gym/trainer for personalized training and with required legal authorities.',
    ),
    ExpandableCardData(
      title: '4. Data Security',
      content: 'We use Firebase services with encryption. However, no system is 100% secure.',
    ),
    ExpandableCardData(
      title: '5. Your Rights',
      content: 'You can access, correct, delete, or export your data under DPDP Act, India.',
    ),
  ];

  final Map<int, bool> _expandedTerms = {};
  final Map<int, bool> _expandedPrivacy = {};

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Privacy'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isLargeScreen ? 24.0 : 16.0,
          vertical: 16.0,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    children: [
                      Text(
                        'Fitnophedia Terms & Privacy',
                        style: TextStyle(
                          fontSize: isLargeScreen ? 24 : 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Last Updated: 12 December 2025',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          fontSize: isLargeScreen ? 15 : 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: isLargeScreen ? 32 : 24),

              // Responsive Layout
              if (isLargeScreen)
                _buildDesktopLayout(isDarkMode)
              else
                _buildMobileLayout(isDarkMode),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDarkMode) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Terms Section
        Expanded(
          child: _buildSection(
            title: 'Terms & Conditions',
            cards: _termsCards,
            expandedMap: _expandedTerms,
            isDarkMode: isDarkMode,
          ),
        ),
        const SizedBox(width: 24),

        // Privacy Section
        Expanded(
          child: _buildSection(
            title: 'Privacy Policy',
            cards: _privacyCards,
            expandedMap: _expandedPrivacy,
            isDarkMode: isDarkMode,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDarkMode) {
    return Column(
      children: [
        // Terms Section
        _buildSection(
          title: 'Terms & Conditions',
          cards: _termsCards,
          expandedMap: _expandedTerms,
          isDarkMode: isDarkMode,
        ),
        const SizedBox(height: 32),

        // Privacy Section
        _buildSection(
          title: 'Privacy Policy',
          cards: _privacyCards,
          expandedMap: _expandedPrivacy,
          isDarkMode: isDarkMode,
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required List<ExpandableCardData> cards,
    required Map<int, bool> expandedMap,
    required bool isDarkMode,
  }) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: isDarkMode
            ? null
            : [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(isLargeScreen ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isLargeScreen ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(cards.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildExpandableCard(
                title: cards[index].title,
                content: cards[index].content,
                isExpanded: expandedMap[index] ?? false,
                onTap: () {
                  setState(() {
                    expandedMap[index] = !(expandedMap[index] ?? false);
                  });
                },
                isDarkMode: isDarkMode,
                isLargeScreen: isLargeScreen,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildExpandableCard({
    required String title,
    required String content,
    required bool isExpanded,
    required VoidCallback onTap,
    required bool isDarkMode,
    required bool isLargeScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.grey[900]
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey[800]!
              : Colors.grey[300]!,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isLargeScreen ? 17 : 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Container(
                    height: 1,
                    color: isDarkMode
                        ? Colors.grey[800]
                        : Colors.grey[200],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    content,
                    style: TextStyle(
                      fontSize: isLargeScreen ? 15 : 14,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeSection() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 600;
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.orange.withOpacity(0.1)
            : Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.orange.withOpacity(0.3)
              : Colors.orange[200]!,
        ),
      ),
      padding: EdgeInsets.all(isLargeScreen ? 20 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: isDarkMode ? Colors.orange[300] : Colors.orange[700],
            size: isLargeScreen ? 24 : 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'By using Fitnophedia, you agree to these terms and privacy policy.',
              style: TextStyle(
                fontSize: isLargeScreen ? 15 : 14,
                color: isDarkMode
                    ? Colors.orange[200]
                    : Colors.orange[900],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpandableCardData {
  final String title;
  final String content;

  ExpandableCardData({required this.title, required this.content});
}