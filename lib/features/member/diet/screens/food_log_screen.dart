import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:uuid/uuid.dart';

import '../models/nutrition_models.dart';
import '../repository/nutrition_repository.dart';
import 'barcode_scan_screen.dart';

class FoodLogScreen extends StatefulWidget {
  final String gymId;
  final String memberId;
  final DateTime date;
  final String mealTime; // e.g., "Breakfast", "Lunch"

  const FoodLogScreen({
    Key? key,
    required this.gymId,
    required this.memberId,
    required this.date,
    required this.mealTime,
  }) : super(key: key);

  @override
  State<FoodLogScreen> createState() => _FoodLogScreenState();
}

class _FoodLogScreenState extends State<FoodLogScreen> {
  late final NutritionRepository _repo;
  final TextEditingController _searchController = TextEditingController();
  
  // Mock Data
  final List<Map<String, dynamic>> _allFoods = [
    {"name": "Oatmeal", "cal": 150, "p": 5, "c": 27, "f": 3},
    {"name": "Banana", "cal": 105, "p": 1.3, "c": 27, "f": 0.3},
    {"name": "Chicken Breast", "cal": 165, "p": 31, "c": 0, "f": 3.6},
    {"name": "Rice (White)", "cal": 130, "p": 2.7, "c": 28, "f": 0.3},
    {"name": "Protein Shake", "cal": 120, "p": 24, "c": 3, "f": 1},
    {"name": "Almonds (30g)", "cal": 170, "p": 6, "c": 6, "f": 15},
    {"name": "Greek Yogurt", "cal": 100, "p": 10, "c": 3, "f": 0},
    {"name": "Eggs (Large)", "cal": 70, "p": 6, "c": 0, "f": 5},
    {"name": "Avocado Toast", "cal": 250, "p": 6, "c": 20, "f": 18},
    {"name": "Salmon", "cal": 200, "p": 22, "c": 0, "f": 13},
  ];

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _repo = NutritionRepository(
      gymId: widget.gymId,
      memberId: widget.memberId,
    );
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _isSearching = false;
        _searchResults = [];
      } else {
        _isSearching = true;
        _searchResults = _allFoods.where((food) {
          return food['name'].toString().toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _onFoodSelected(Map<String, dynamic> food) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildFoodDetailsSheet(food),
    );
  }

  Future<void> _onScanBarcode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScanScreen()),
    );

    if (result != null) {
      // Mock barcode lookup
      final mockFood = {
        "name": "Scanned Product ($result)",
        "cal": 200,
        "p": 10,
        "c": 25,
        "f": 5
      };
      _onFoodSelected(mockFood);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Log ${widget.mealTime}",
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Iconsax.scan_barcode, size: 24),
            color: textColor,
            onPressed: _onScanBarcode,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(fontFamily: 'Outfit', color: textColor),
                decoration: InputDecoration(
                  hintText: "Search food (e.g. 'Avocado Toast')",
                  hintStyle: TextStyle(fontFamily: 'Outfit', color: Colors.grey),
                  prefixIcon: const Icon(Iconsax.search_normal, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            FocusScope.of(context).unfocus();
                          },
                        )
                      : null,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isSearching
                ? _buildSearchResults(textColor, cardColor)
                : _buildDefaultView(textColor, cardColor, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(Color textColor, Color cardColor) {
    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "No foods found",
          style: TextStyle(fontFamily: 'Outfit', color: Colors.grey),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final food = _searchResults[index];
        return GestureDetector(
          onTap: () => _onFoodSelected(food),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food['name'],
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    Text(
                      "${food['cal']} kcal • ${food['p']}g P • ${food['c']}g C • ${food['f']}g F",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Icon(Iconsax.add_circle, color: Color(0xFF00E676)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultView(Color textColor, Color cardColor, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recent Foods Section
          Text(
            "Recent Foods",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _allFoods.take(5).length,
              itemBuilder: (context, index) {
                return _buildRecentFoodItem(_allFoods[index], isDark);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Categories / Quick Add
          Text(
            "Quick Add",
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickAddTile("Favorites", Iconsax.heart, Colors.redAccent, isDark),
          _buildQuickAddTile("My Meals", Iconsax.note_favorite, Colors.orangeAccent, isDark),
          _buildQuickAddTile("Create New", Iconsax.add_circle, const Color(0xFF00E676), isDark),
        ],
      ),
    );
  }

  Widget _buildRecentFoodItem(Map<String, dynamic> food, bool isDark) {
    return GestureDetector(
      onTap: () => _onFoodSelected(food),
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Iconsax.cake, size: 24, color: isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              food['name'],
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodDetailsSheet(Map<String, dynamic> food) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            food['name'],
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "1 Serving (100g)", // Mock serving
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMacroCircle("Calories", "${food['cal']}", const Color(0xFF00E676), isDark),
              _buildMacroCircle("Protein", "${food['p']}g", Colors.blueAccent, isDark),
              _buildMacroCircle("Carbs", "${food['c']}g", Colors.orangeAccent, isDark),
              _buildMacroCircle("Fats", "${food['f']}g", Colors.purpleAccent, isDark),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Added ${food['name']} to ${widget.mealTime}"),
                    backgroundColor: const Color(0xFF00E676),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Add to Log",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroCircle(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAddTile(String title, IconData icon, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const Spacer(),
          Icon(Iconsax.arrow_right_3, color: Colors.grey, size: 18),
        ],
      ),
    );
  }
}
