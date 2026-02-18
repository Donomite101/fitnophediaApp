import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:image_picker/image_picker.dart';

class MediaPickerWidget extends StatefulWidget {
  final Function(AssetEntity?, File?) onAssetSelected;
  const MediaPickerWidget({Key? key, required this.onAssetSelected}) : super(key: key);

  @override
  State<MediaPickerWidget> createState() => _MediaPickerWidgetState();
}

class _MediaPickerWidgetState extends State<MediaPickerWidget> {
  List<AssetPathEntity> _paths = [];
  AssetPathEntity? _selectedPath;
  List<AssetEntity> _assets = [];
  AssetEntity? _selectedAsset;
  File? _capturedFile;
  bool _loading = true;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    final PermissionState ps = await PhotoManager.requestPermissionExtend();
    if (ps.isAuth) {
      final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );
      if (paths.isNotEmpty) {
        if (mounted) {
          setState(() {
            _paths = paths;
            _selectedPath = paths[0];
          });
          _fetchAssetsFromPath(_selectedPath!);
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      PhotoManager.openSetting();
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchAssetsFromPath(AssetPathEntity path) async {
    setState(() => _loading = true);
    final List<AssetEntity> entities = await path.getAssetListPaged(
      page: 0,
      size: 200, // Load more assets
    );
    if (mounted) {
      setState(() {
        _assets = entities;
        if (_assets.isNotEmpty) {
          _selectedAsset = _assets[0];
          widget.onAssetSelected(_selectedAsset!, null);
        }
        _loading = false;
      });
    }
  }

  Future<void> _takePhoto() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _capturedFile = File(photo.path);
        _selectedAsset = null;
      });
      widget.onAssetSelected(null, _capturedFile);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.green));
    }

    return Column(
      children: [
        // Preview
        Stack(
          children: [
            Container(
              height: MediaQuery.of(context).size.width,
              width: double.infinity,
              color: Colors.black,
              child: _capturedFile != null
                  ? Image.file(_capturedFile!, fit: BoxFit.cover)
                  : (_selectedAsset != null
                      ? AssetEntityImage(
                          _selectedAsset!,
                          isOriginal: true,
                          fit: BoxFit.cover,
                        )
                      : const Center(child: Icon(Icons.image, color: Colors.white24, size: 50))),
            ),
            if (_paths.isNotEmpty)
              Positioned(
                bottom: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<AssetPathEntity>(
                      value: _selectedPath,
                      dropdownColor: Colors.black,
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 20),
                      items: _paths.map((path) {
                        return DropdownMenuItem(
                          value: path,
                          child: Text(
                            path.name.isEmpty ? 'Recent' : path.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: (newPath) {
                        if (newPath != null) {
                          setState(() {
                            _selectedPath = newPath;
                            _capturedFile = null;
                          });
                          _fetchAssetsFromPath(newPath);
                        }
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
        const Divider(height: 1, color: Colors.white12),
        // Grid
        Expanded(
          child: GridView.builder(
            itemCount: _assets.length + 1, // +1 for Camera
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: _takePhoto,
                  child: Container(
                    color: Colors.grey[900],
                    child: const Icon(Icons.camera_alt, color: Colors.white),
                  ),
                );
              }

              final asset = _assets[index - 1];
              final isSelected = _selectedAsset == asset;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAsset = asset;
                    _capturedFile = null;
                  });
                  widget.onAssetSelected(asset, null);
                },
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AssetEntityImage(
                        asset,
                        isOriginal: false,
                        thumbnailSize: const ThumbnailSize.square(200),
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (isSelected)
                      Positioned.fill(
                        child: Container(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
