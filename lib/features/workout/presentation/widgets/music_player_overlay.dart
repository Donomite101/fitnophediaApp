import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import '../../data/services/music_service.dart';

class MusicPlayerOverlay extends StatefulWidget {
  const MusicPlayerOverlay({Key? key}) : super(key: key);

  @override
  State<MusicPlayerOverlay> createState() => _MusicPlayerOverlayState();
}

class _MusicPlayerOverlayState extends State<MusicPlayerOverlay> {
  // Local state for smooth dragging
  Offset? _dragPosition;
  bool _isDraggingLocal = false;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double expandedHeight = 350; // Increased height
    final double expandedWidth = size.width - 32;
    final double miniSize = 60;

    // Wrap in Provider to allow Selectors
    return ChangeNotifierProvider.value(
      value: MusicService.instance,
      child: Stack(
        children: [
          // 1. Expanded/Collapsed Logic & Layout (Rebuilds on isExpanded/fabPosition/showList change)
          Selector<MusicService, Map<String, dynamic>>(
            selector: (_, service) => {
              'isExpanded': service.isExpanded,
              'fabPosition': service.fabPosition,
              'showList': service.showList,
              'isDragging': service.isDragging,
            },
            builder: (context, data, child) {
              final isExpanded = data['isExpanded'] as bool;
              final fabPosition = data['fabPosition'] as Offset?;
              final showList = data['showList'] as bool;
              final isDraggingService = data['isDragging'] as bool;

              // Determine position: Use local drag position if dragging, otherwise service position
              Offset fabPos = _isDraggingLocal 
                  ? (_dragPosition ?? Offset.zero) 
                  : (fabPosition ?? Offset(size.width - miniSize - 16, 100));

              // Calculate expanded position based on drag position (clamped to screen)
              double expandedTop = 0;
              double centerY = fabPos.dy + miniSize / 2;
              expandedTop = centerY - expandedHeight / 2;
              expandedTop = expandedTop.clamp(50.0, size.height - expandedHeight - 50.0);

              return Stack(
                children: [
                  // Tap outside to minimize
                  if (isExpanded)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => MusicService.instance.setExpanded(false),
                        behavior: HitTestBehavior.translucent,
                        child: Container(color: Colors.transparent),
                      ),
                    ),

                  AnimatedPositioned(
                    duration: _isDraggingLocal ? Duration.zero : const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    left: isExpanded ? 16 : fabPos.dx,
                    top: isExpanded ? expandedTop : fabPos.dy,
                    width: isExpanded ? expandedWidth : miniSize,
                    height: isExpanded ? expandedHeight : miniSize,
                    child: RepaintBoundary(
                      child: Material(
                        color: Colors.transparent,
                        elevation: isExpanded ? 20 : 10,
                        shadowColor: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(isExpanded ? 24 : 30), // Circle when mini
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(isExpanded ? 24 : 30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isExpanded ? Colors.black.withOpacity(0.8) : Colors.grey[900],
                                borderRadius: BorderRadius.circular(isExpanded ? 24 : 30),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                                boxShadow: isExpanded ? [] : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: isExpanded 
                                ? (showList 
                                    ? _buildSongList(context) 
                                    : _buildCompactPlayer(context))
                                : _buildMiniPlayer(context, size, miniSize),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer(BuildContext context, Size screenSize, double miniSize) {
    final service = MusicService.instance;
    
    return GestureDetector(
      key: const ValueKey('mini'),
      onPanStart: (details) {
        setState(() {
          _isDraggingLocal = true;
          _dragPosition = service.fabPosition ?? Offset(screenSize.width - miniSize - 16, 100);
        });
      },
      onPanUpdate: (details) {
        setState(() {
          final curr = _dragPosition ?? Offset.zero;
          _dragPosition = Offset(
            (curr.dx + details.delta.dx).clamp(0.0, screenSize.width - miniSize),
            (curr.dy + details.delta.dy).clamp(0.0, screenSize.height - miniSize),
          );
        });
      },
      onPanEnd: (details) {
        setState(() {
          _isDraggingLocal = false;
        });
        if (_dragPosition != null) {
          service.setFabPosition(_dragPosition!);
        }
      },
      onTap: () => service.setExpanded(true),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Artwork - Only rebuilds when song ID changes
          Selector<MusicService, int?>(
            selector: (_, service) => service.currentSong?.id,
            builder: (context, songId, child) {
              return QueryArtworkWidget(
                key: ValueKey(songId),
                id: songId ?? 0,
                type: ArtworkType.AUDIO,
                keepOldArtwork: true,
                artworkFit: BoxFit.cover,
                artworkBorder: BorderRadius.circular(30), // Circle for Mini Player
                nullArtworkWidget: Container(
                  decoration: const BoxDecoration(
                    color: Colors.grey,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Iconsax.music, color: Colors.white24, size: 24),
                ),
              );
            },
          ),
          
          // Overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
          ),
          
          // Play/Pause Icon - Only rebuilds when isPlaying changes
          Selector<MusicService, bool>(
            selector: (_, service) => service.isPlaying,
            builder: (context, isPlaying, child) {
              return Icon(
                isPlaying ? Iconsax.pause : Iconsax.play,
                color: Colors.white,
                size: 24,
              );
            },
          ),
          
          // Circular Progress Indicator (Back to Circle)
          Selector<MusicService, double>(
            selector: (_, service) => (service.totalDuration.inMilliseconds > 0) 
                ? service.currentPosition.inMilliseconds / service.totalDuration.inMilliseconds 
                : 0.0,
            builder: (context, progress, child) {
              return IgnorePointer(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 3,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E676)),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCompactPlayer(BuildContext context) {
    final service = MusicService.instance;
    return LayoutBuilder(
      key: const ValueKey('expanded'),
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) return const SizedBox();

        return Selector<MusicService, SongModel?>(
          selector: (_, service) => service.currentSong,
          builder: (context, song, child) {
            if (song == null) return _buildSongList(context);

            return GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 10) {
                  service.setExpanded(false);
                }
              },
              behavior: HitTestBehavior.translucent,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Drag Handle
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Header with Browse Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                         GestureDetector(
                          onTap: () => service.setShowList(true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Iconsax.music_playlist, color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  "Browse",
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Artwork
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: Colors.grey[900],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: QueryArtworkWidget(
                                id: song.id,
                                type: ArtworkType.AUDIO,
                                artworkBorder: BorderRadius.circular(16), // Explicitly Square
                                nullArtworkWidget: const Icon(Iconsax.music, size: 32, color: Colors.white24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Info & Controls
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  song.artist ?? "Unknown",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Outfit',
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Iconsax.previous, color: Colors.white, size: 24),
                                        onPressed: () => service.playPrevious(),
                                      ),
                                      const SizedBox(width: 16),
                                      
                                      // Play/Pause Button
                                      Selector<MusicService, bool>(
                                        selector: (_, s) => s.isPlaying,
                                        builder: (context, isPlaying, _) {
                                          return GestureDetector(
                                            onTap: () => service.togglePlayPause(),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Color(0xFF00E676),
                                              ),
                                              child: Icon(
                                                isPlaying ? Iconsax.pause : Iconsax.play,
                                                color: Colors.black,
                                                size: 20,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      
                                      const SizedBox(width: 16),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Iconsax.next, color: Colors.white, size: 24),
                                        onPressed: () => service.playNext(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Progress Bar (Slim)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Selector<MusicService, Map<String, Duration>>(
                      selector: (_, s) => {'pos': s.currentPosition, 'dur': s.totalDuration},
                      builder: (context, data, _) {
                        final position = data['pos']!;
                        final duration = data['dur']!;
                        return Row(
                          children: [
                            Text(
                              _formatDuration(position),
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                  activeTrackColor: const Color(0xFF00E676),
                                  inactiveTrackColor: Colors.white.withOpacity(0.1),
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: position.inSeconds.toDouble().clamp(0.0, duration.inSeconds.toDouble()),
                                  max: duration.inSeconds.toDouble() > 0 ? duration.inSeconds.toDouble() : 1.0,
                                  onChanged: (value) {
                                    service.seek(Duration(seconds: value.toInt()));
                                  },
                                ),
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSongList(BuildContext context) {
    final service = MusicService.instance;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 300) {
          return const SizedBox();
        }
        
        return Column(
          children: [
            // Header with Drag to Minimize
            GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 10) {
                  service.setExpanded(false);
                }
              },
              behavior: HitTestBehavior.translucent,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button (if playing)
                    Selector<MusicService, bool>(
                      selector: (_, s) => s.currentSong != null,
                      builder: (context, hasSong, _) {
                        if (!hasSong) return const SizedBox();
                        return GestureDetector(
                          onTap: () => service.setShowList(false),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Iconsax.arrow_left, color: Colors.white, size: 20),
                          ),
                        );
                      },
                    ),
                      
                    Text(
                      "Music Library",
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    
                    // Close Button
                    GestureDetector(
                      onTap: () => service.setExpanded(false),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Iconsax.close_circle, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // List
            Expanded(
              child: Selector<MusicService, List<SongModel>>(
                selector: (_, s) => s.songs,
                builder: (context, songs, _) {
                  if (songs.isEmpty) {
                    return Center(
                      child: Text(
                        "No songs found",
                        style: TextStyle(color: Colors.white.withOpacity(0.5)),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      return Selector<MusicService, int?>(
                        selector: (_, s) => s.currentSong?.id,
                        builder: (context, currentSongId, _) {
                          final isSelected = currentSongId == song.id;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF00E676).withOpacity(0.1) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected ? Border.all(color: const Color(0xFF00E676).withOpacity(0.3)) : null,
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              leading: SizedBox(
                                width: 48,
                                height: 48,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: QueryArtworkWidget(
                                    id: song.id,
                                    type: ArtworkType.AUDIO,
                                    nullArtworkWidget: Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey[900],
                                      child: const Icon(Iconsax.music, color: Colors.white24, size: 20),
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF00E676) : Colors.white, 
                                  fontFamily: 'Outfit', 
                                  fontWeight: FontWeight.w500
                                ),
                              ),
                              subtitle: Text(
                                song.artist ?? "Unknown",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                              ),
                              onTap: () {
                                service.playSong(index);
                                service.setShowList(false); // Reset to player view
                                service.setExpanded(false); // Auto-minimize
                              },
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}

