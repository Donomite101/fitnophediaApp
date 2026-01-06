import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fitnophedia/features/member/streak/service/challenges_section.dart';
import 'models/streak_view_model.dart';
import 'widgets/streak_header.dart';
import 'widgets/calendar_widget.dart';

class StreakScreen extends StatefulWidget {
  final String gymId;
  final String memberId;

  const StreakScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
  }) : super(key: key);

  @override
  State<StreakScreen> createState() => _StreakScreenState();
}

class _StreakScreenState extends State<StreakScreen> {
  late StreakViewModel _viewModel;
  late StreamSubscription<bool> _themeSubscription;

  @override
  void initState() {
    super.initState();
    _viewModel = StreakViewModel(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.loadStreakData();
    _themeSubscription = _viewModel.themeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _onViewModelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _viewModel.updateTheme(context);
  }

  @override
  void dispose() {
    _themeSubscription.cancel();
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _viewModel.backgroundColor,
      appBar: AppBar(
        backgroundColor: _viewModel.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: _viewModel.textColor,
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Achievements',
          style: TextStyle(
            color: _viewModel.textColor,
            fontSize: 20,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _viewModel.isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: _viewModel.primaryBlue),
              const SizedBox(height: 20),
              Text(
                'Loading your achievements...',
                style: TextStyle(
                  color: _viewModel.textColor,
                  fontSize: 16,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(height: 10),
              FutureBuilder<Map<String, dynamic>>(
                future: _viewModel.getBadgeStats(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    final stats = snapshot.data!;
                    return Text(
                      '${stats['totalUnlocked'] ?? 0}/${stats['totalBadges'] ?? 0} badges unlocked',
                      style: TextStyle(
                        color: _viewModel.secondaryTextColor,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    );
                  }
                  return Container();
                },
              ),
            ],
          ),
        )
            : SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // FIX: Add the required gymId and memberId parameters
              StreakHeader(
                viewModel: _viewModel,
                gymId: widget.gymId,      // Add this
                memberId: widget.memberId, // Add this
              ),
              const SizedBox(height: 20),
              ChallengesSection(
                viewModel: _viewModel,
                gymId: widget.gymId,      // Add this
                memberId: widget.memberId, // Add this
              ),              const SizedBox(height: 20),
              CalendarWidget(viewModel: _viewModel),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}