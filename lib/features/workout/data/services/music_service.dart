import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';

class MusicService extends ChangeNotifier {
  MusicService._();
  static final MusicService instance = MusicService._();

  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  List<SongModel> _songs = [];
  int _currentIndex = -1;
  bool _isPlaying = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  List<SongModel> get songs => _songs;
  SongModel? get currentSong => _currentIndex != -1 ? _songs[_currentIndex] : null;
  bool get isPlaying => _isPlaying;
  Duration get currentPosition => _currentPosition;
  Duration get totalDuration => _totalDuration;
  
  // UI State
  bool _isExpanded = true;
  Offset? _fabPosition;
  
  bool get isExpanded => _isExpanded;
  Offset? get fabPosition => _fabPosition;

  void setExpanded(bool value) {
    _isExpanded = value;
    notifyListeners();
  }

  void setFabPosition(Offset position) {
    _fabPosition = position;
    notifyListeners();
  }

  // Dragging State
  bool _isDragging = false;
  bool get isDragging => _isDragging;

  void setDragging(bool value) {
    _isDragging = value;
    notifyListeners();
  }

  // Browse State
  bool _showList = false;
  bool get showList => _showList;

  void setShowList(bool value) {
    _showList = value;
    notifyListeners();
  }

  Future<void> init() async {
    await _requestPermission();
    await _fetchSongs();
    
    _audioPlayer.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
      notifyListeners();
    });

    _audioPlayer.onDurationChanged.listen((d) {
      _totalDuration = d;
      notifyListeners();
    });

    _audioPlayer.onPositionChanged.listen((p) {
      _currentPosition = p;
      notifyListeners();
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      playNext();
    });
  }

  Future<void> _requestPermission() async {
    // Request permissions for reading audio files
    // For Android 13+, use photos/audio/videos permissions
    // For older versions, use storage
    
    // Note: permission_handler handles SDK version checks internally for some permissions,
    // but explicit checks are safer for media.
    
    // Simple check for now, can be expanded
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
    
    // Also try audio permission for Android 13+
    var audioStatus = await Permission.audio.status;
    if (!audioStatus.isGranted) {
      await Permission.audio.request();
    }
  }

  Future<void> _fetchSongs() async {
    try {
      _songs = await _audioQuery.querySongs(
        sortType: SongSortType.DATE_ADDED,
        orderType: OrderType.DESC_OR_GREATER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );
      // Filter out short audio clips (e.g., less than 30 seconds)
      _songs = _songs.where((song) => (song.duration ?? 0) > 30000).toList();
      notifyListeners();
    } catch (e) {
      debugPrint("Error fetching songs: $e");
    }
  }

  Future<void> playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;

    try {
      _currentIndex = index;
      final song = _songs[_currentIndex];
      
      // OnAudioQuery provides a URI, but AudioPlayer needs a path or source.
      // For local files, we can usually use the data path.
      // However, newer Android versions might restrict direct path access.
      // Let's try setting source by device file path first.
      
      await _audioPlayer.setSourceDeviceFile(song.data);
      await _audioPlayer.resume();
      notifyListeners();
    } catch (e) {
      debugPrint("Error playing song: $e");
    }
  }

  Future<void> togglePlayPause() async {
    if (_currentIndex == -1 && _songs.isNotEmpty) {
      playSong(0);
      return;
    }

    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      if (_audioPlayer.state == PlayerState.paused) {
        await _audioPlayer.resume();
      } else {
        await playSong(_currentIndex);
      }
    }
  }

  Future<void> stop() async {
    await _audioPlayer.stop();
    _isPlaying = false;
    notifyListeners();
  }

  Future<void> playNext() async {
    if (_songs.isEmpty) return;
    int nextIndex = (_currentIndex + 1) % _songs.length;
    await playSong(nextIndex);
  }

  Future<void> playPrevious() async {
    if (_songs.isEmpty) return;
    int prevIndex = (_currentIndex - 1);
    if (prevIndex < 0) prevIndex = _songs.length - 1;
    await playSong(prevIndex);
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }
  
  // Helper to get artwork
  Widget getArtwork(int id) {
    return QueryArtworkWidget(
      id: id,
      type: ArtworkType.AUDIO,
      nullArtworkWidget: const Icon(Icons.music_note, size: 50, color: Colors.white24),
    );
  }
}
