import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:fitnophedia/features/community/data/services/community_service.dart';

class ManageAdsScreen extends StatefulWidget {
  final String gymId;
  final String gymName;

  const ManageAdsScreen({Key? key, required this.gymId, required this.gymName}) : super(key: key);

  @override
  State<ManageAdsScreen> createState() => _ManageAdsScreenState();
}

class _ManageAdsScreenState extends State<ManageAdsScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String _adType = 'GymOnly'; // Default

  Future<void> _uploadAd() async {
    final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isUploading = true);

    final mediaUrl = await CommunityService.instance.uploadMedia(File(file.path), resourceType: 'image');

    if (mediaUrl != null) {
      await CommunityService.instance.createAd(
        gymId: widget.gymId,
        gymName: widget.gymName,
        mediaUrl: mediaUrl,
        type: _adType,
      );
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad uploaded successfully!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed')));
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MANAGE ADS', style: GoogleFonts.bebasNeue()),
      ),
      body: _isUploading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Advertisements', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: CommunityService.instance.getActiveAds(gymId: widget.gymId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      final ads = snapshot.data!;
                      if (ads.isEmpty) return const Center(child: Text('No active ads'));

                      return ListView.builder(
                        itemCount: ads.length,
                        itemBuilder: (context, index) {
                          final ad = ads[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: Image.network(ad['mediaUrl'], width: 50, height: 50, fit: BoxFit.cover),
                              title: Text(ad['type']),
                              subtitle: Text('Status: ${ad['status']}'),
                              trailing: const Icon(Iconsax.trash, color: Colors.red),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Create New Advertisement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Local'),
                        value: 'GymOnly',
                        groupValue: _adType,
                        onChanged: (v) => setState(() => _adType = v!),
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<String>(
                        title: const Text('Global'),
                        value: 'Global',
                        groupValue: _adType,
                        onChanged: (v) => setState(() => _adType = v!),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _uploadAd,
                    icon: const Icon(Iconsax.add_circle),
                    label: const Text('UPLOAD AD MEDIA'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
