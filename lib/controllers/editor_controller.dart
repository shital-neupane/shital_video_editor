import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:shital_video_editor/models/export_options.dart';
import 'package:shital_video_editor/models/project.dart';
import 'package:shital_video_editor/models/text.dart';
import 'package:shital_video_editor/routes/app_pages.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
import 'package:shital_video_editor/shared/helpers/ffmpeg.dart';
import 'package:shital_video_editor/shared/helpers/files.dart';
import 'package:shital_video_editor/shared/helpers/snackbar.dart';
import 'package:shital_video_editor/shared/helpers/video.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/translations/translation_keys.dart'
    as translations;

import 'package:intl/intl.dart';
import 'package:shital_video_editor/pages/editor/widgets/audio_start_sheet.dart';
import 'package:video_player/video_player.dart';

class EditorController extends GetxController {
  EditorController({required this.project});

  // Project that will be worked on.
  final Project project;
  // Cached project media file.
  File? projectMediaFile;

  static EditorController get to => Get.find();

  bool get isMediaNetworkPath => isNetworkPath(project.mediaUrl);

  int get photoDuration => project.photoDuration;

  // Video controller for the video player (if needed).
  VideoPlayerController? _videoController;
  ScrollController scrollController = ScrollController();

  Duration? _position = Duration(seconds: 0);
  double timelineScale = 50.0;
  double _baseScale = 50.0;
  bool isTimelineScrollLocked = false;
  bool _isUserScrolling = false;
  bool _isAutoScrolling = false;
  int _lastSeekMs = -1;
  DateTime _lastManualSeekTime =
      DateTime.now().subtract(const Duration(seconds: 1));
  Timer? _scrollDebounceTimer;

  get videoController => _videoController;
  bool get isVideoInitialized =>
      _videoController != null && _videoController!.value.isInitialized;
  bool get isVideoPlaying =>
      _videoController != null && _videoController!.value.isPlaying;
  double get videoAspectRatio =>
      isVideoInitialized ? _videoController!.value.aspectRatio : 1.0;
  double get videoPosition => (_position!.inMilliseconds.toDouble() / 1000);
  int get msVideoPosition => _position!.inMilliseconds;
  double get videoDuration => isVideoInitialized
      ? _videoController!.value.duration.inSeconds.toDouble()
      : 0.0;
  double get videoDurationMs => isVideoInitialized
      ? _videoController!.value.duration.inMilliseconds.toDouble()
      : 0.0;
  int get exportVideoDuration =>
      isVideoInitialized ? _videoController!.value.duration.inMilliseconds : 0;
  int get afterExportVideoDuration =>
      project.transformations.trimEnd.inMilliseconds -
      project.transformations.trimStart.inMilliseconds;

  String get videoPositionString => formatTime(_position!.inSeconds);
  String get videoDurationString => isVideoInitialized
      ? formatTime(_videoController!.value.duration.inSeconds)
      : '00:00';

  bool get isHorizontal => videoWidth > videoHeight;
  double get scalingFactor => isHorizontal
      ? videoWidth / (Get.width - 2 * 8.0)
      : videoHeight / (Get.height * 0.4);

  // Variables to control the export process.
  int _bitrate = 2;
  int get bitrate => _bitrate;
  set bitrate(int bitrate) {
    _bitrate = bitrate;
    update();
  }

  bool _bitrateActive = false;
  bool get bitrateActive => _bitrateActive;
  set bitrateActive(bool bitrateActive) {
    _bitrateActive = bitrateActive;
    update();
  }

  int _fps = 2;
  int get fps => _fps;
  set fps(int fps) {
    _fps = fps;
    update();
  }

  bool _fpsActive = false;
  bool get fpsActive => _fpsActive;
  set fpsActive(bool fpsActive) {
    _fpsActive = fpsActive;
    update();
  }

  // Set editor options
  SelectedOptions _selectedOptions = SelectedOptions.BASE;
  SelectedOptions get selectedOptions => _selectedOptions;
  set selectedOptions(SelectedOptions selectedOptions) {
    _selectedOptions = selectedOptions;
    update();
  }

  // Trim options
  int get trimStart => project.transformations.trimStart.inMilliseconds;
  int get trimEnd => project.transformations.trimEnd.inMilliseconds;

  // Audio options
  AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioInitialized = false;
  ScrollController audioScrollController = ScrollController();

  Duration _audioDuration = Duration.zero;
  Duration audioPosition = Duration.zero;
  int get sAudioDuration => _audioDuration.inSeconds;
  int get msAudioEnd => audioStart.inMilliseconds + afterExportVideoDuration;

  // Used for the progress bar in the audio start bottom sheet
  int get relativeAudioPosition =>
      audioPosition.inMilliseconds - audioStart.inMilliseconds;
  bool get canSetAudioStart =>
      hasAudio &&
      isAudioInitialized &&
      sAudioDuration > (afterExportVideoDuration / 1000);

  PlayerState? _audioPlayerState;
  PlayerState get audioPlayerState => _audioPlayerState ?? PlayerState.stopped;
  set audioPlayerState(PlayerState audioPlayerState) {
    _audioPlayerState = audioPlayerState;
    update();
  }

  bool get isAudioPlaying => _audioPlayerState == PlayerState.playing;

  Duration get audioStart => project.transformations.audioStart;

  bool get hasAudio => project.transformations.audioUrl.isNotEmpty;
  bool get isAudioInitialized => _isAudioInitialized;
  set isAudioInitialized(bool isAudioInitialized) {
    _isAudioInitialized = isAudioInitialized;
    update();
  }

  double get masterVolume => project.transformations.masterVolume;
  set masterVolume(double masterVolume) {
    project.transformations.masterVolume = masterVolume;
    videoController.setVolume(masterVolume);
    update();
  }

  double get audioVolume => project.transformations.audioVolume;
  set audioVolume(double audioVolume) {
    project.transformations.audioVolume = audioVolume;
    _audioPlayer.setVolume(audioVolume);
    update();
  }

  String get audioName => project.transformations.audioName;

  // ------------------ TEXT VARIABLES ------------------------

  String _textToAdd = '';
  String get textToAdd => _textToAdd;
  set textToAdd(String value) {
    _textToAdd = value;
    update();
  }

  int _textDuration = 5;
  int get textDuration => _textDuration;
  set textDuration(int value) {
    _textDuration = value;
    update();
  }

  String _selectedTextId = '';
  String get selectedTextId => _selectedTextId;
  set selectedTextId(String value) {
    _selectedTextId = value;
    update();
  }

  get hasText => project.transformations.texts.isNotEmpty;
  get texts => List<TextTransformation>.from(project.transformations.texts)
    ..sort(textComparator);
  get nTexts => project.transformations.texts.length;
  get selectedText => project.transformations.texts
      .firstWhere((element) => element.id == selectedTextId);
  get selectedTextContent => selectedText.text;
  get selectedTextStartTime => selectedText.msStartTime;
  int get selectedTextDuration => selectedText.msDuration;
  get selectedTextFontSize => selectedText.fontSize;
  get selectedTextColor => selectedText.color;
  get selectedTextBackgroundColor => selectedText.backgroundColor;
  get selectedTextPosition => selectedText.position;
  get maxSelectedTextDuration => trimEnd - selectedTextStartTime;

  get videoWidth => _videoController!.value.size.width;
  get videoHeight => _videoController!.value.size.height;

  get newStartWillOverlap => msVideoPosition + selectedTextDuration > trimEnd;
  get isTooCloseToEnd =>
      msVideoPosition >=
      trimEnd - 100; // Do not let users add text 100 ms close to the end.

  int textComparator(TextTransformation a, TextTransformation b) {
    if (selectedTextId == a.id) return 1;
    if (selectedTextId == b.id) return -1;
    return a.msStartTime.compareTo(b.msStartTime);
  }

  // ------------------ END TEXT VARIABLES ------------------------

  // ------------------ CROP VARIABLES ------------------------

  bool get isCropped =>
      project.transformations.cropWidth != videoWidth ||
      project.transformations.cropHeight != videoHeight;

  final GlobalKey cropKey = GlobalKey();
  final GlobalKey centerKey = GlobalKey();
  final GlobalKey leftTopKey = GlobalKey();
  final GlobalKey topKey = GlobalKey();
  final GlobalKey rightTopKey = GlobalKey();
  final GlobalKey leftKey = GlobalKey();
  final GlobalKey rightKey = GlobalKey();
  final GlobalKey leftBottomKey = GlobalKey();
  final GlobalKey bottomKey = GlobalKey();
  final GlobalKey rightBottomKey = GlobalKey();

  get globalCropPosition =>
      (cropKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalCenterPosition =>
      (centerKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalLeftTopPosition =>
      (leftTopKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalTopPosition =>
      (topKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalTopRightPosition =>
      (rightTopKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalLeftPosition =>
      (leftKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalRightPosition =>
      (rightKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalLeftBottomPosition =>
      (leftBottomKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalBottomPosition =>
      (bottomKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);
  get globalBottomRightPosition =>
      (rightBottomKey.currentContext!.findRenderObject() as RenderBox)
          .localToGlobal(Offset.zero);

  bool _showAudioStartOnLoad = false;

  double _initX = 0;
  double get initX => _initX;
  set initX(double value) {
    _initX = value;
    update();
  }

  double _initY = 0;
  double get initY => _initY;
  set initY(double value) {
    _initY = value;
    update();
  }

  double _initialCropWidth = 0;
  double get initialCropWidth => _initialCropWidth;
  set initialCropWidth(double value) {
    _initialCropWidth = value;
    update();
  }

  double _initialCropHeight = 0;
  double get initialCropHeight => _initialCropHeight;
  set initialCropHeight(double value) {
    _initialCropHeight = value;
    update();
  }

  double _initialCropX = 0;
  double get initialCropX => _initialCropX;
  set initialCropX(double value) {
    _initialCropX = value;
    update();
  }

  double _initialCropY = 0;
  double get initialCropY => _initialCropY;
  set initialCropY(double value) {
    _initialCropY = value;
    update();
  }

  double get cropX => project.transformations.cropX / scalingFactor;
  set cropX(double value) {
    project.transformations.cropX = value * scalingFactor;
    update();
  }

  double get cropY => project.transformations.cropY / scalingFactor;
  set cropY(double value) {
    project.transformations.cropY = value * scalingFactor;
    update();
  }

  double get cropWidth => project.transformations.cropWidth / scalingFactor;
  set cropWidth(double value) {
    project.transformations.cropWidth = value;
    update();
  }

  double get cropHeight => project.transformations.cropHeight / scalingFactor;
  set cropHeight(double value) {
    project.transformations.cropHeight = value;
    update();
  }

  CropAspectRatio get cropAspectRatio =>
      project.transformations.cropAspectRatio;

  // ------------------ END CROP VARIABLES ------------------------

  @override
  void onInit() async {
    print('DEBUG: EditorController onInit started');
    super.onInit();

    // Initialize the video player controller if the project has a video.
    await _initializeVideoController();

    // Initialize the audio player if the project has audio.
    if (hasAudio) {
      _initializeAudio();
    }
    print('DEBUG: EditorController onInit completed');
  }

  @override
  void onClose() {
    print('DEBUG: EditorController onClose called');
    super.onClose();
    // Dispose of the video player controller when the editor is closed.
    _videoController?.dispose();
    _audioPlayer.dispose();
    _videoController = null;
    print('DEBUG: EditorController onClose completed');
  }

  Future<void> _initializeVideoController() async {
    // Only initialize the video player controller if the project media is a video.
    if (!isVideo(project.mediaUrl)) return;

    // For local file paths, initialize directly
    _videoController = VideoPlayerController.file(
      File(project.mediaUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    _videoController!.initialize().then((_) {
      _videoController!.setLooping(false);
      _videoController!.setVolume(masterVolume);

      // If the trim end is 0, set it to the video duration.
      if (project.transformations.trimEnd == Duration.zero) {
        project.transformations.trimEnd = _videoController!.value.duration;
      }

      // If the crop width and height are 0, set them to the video width and height.
      if (project.transformations.cropWidth == 0) {
        project.transformations.cropWidth = _videoController!.value.size.width;
      }
      if (project.transformations.cropHeight == 0) {
        project.transformations.cropHeight =
            _videoController!.value.size.height;
      }

      // Jump to the start if there is a trim start.
      jumpToStart();

      _videoController!.addListener(() {
        if (_videoController == null) return;
        final previousPos = _position;

        // Update the video position every frame.
        _position = _videoController!.value.position;

        // If the position is less than the trim start, jump to the start (if not in trim mode).
        if (_position!.inMilliseconds < trimStart &&
            selectedOptions != SelectedOptions.TRIM) {
          jumpToStart();
          return;
        }

        // Only auto-scroll if the user is not currently scrolling.
        // We sync if the position changed and the user isn't manual dragging the timeline.
        // Also ignore position updates for 150ms after a manual seek to prevent jumping back to stale positions.
        final now = DateTime.now();
        if (!_isUserScrolling &&
            _position != previousPos &&
            now.difference(_lastManualSeekTime).inMilliseconds > 150) {
          // Calculate relative position from trimStart
          double relativeMs =
              (_position!.inMilliseconds - trimStart).toDouble();
          double scrollPosition = (relativeMs * 0.001 * timelineScale);
          _jumpTimeline(scrollPosition);
        }

        update();
      });
      update();
    });

    scrollController.addListener(() {
      if (_isAutoScrolling) return;

      if (scrollController.position.userScrollDirection !=
          ScrollDirection.idle) {
        _isUserScrolling = true;
        _lastManualSeekTime = DateTime.now();
        if (isVideoPlaying) {
          pauseVideo();
        }
        final double relativeSeconds =
            scrollController.position.pixels / timelineScale;
        final int targetMs = (relativeSeconds * 1000).toInt() + trimStart;

        if (targetMs != _lastSeekMs) {
          _lastSeekMs = targetMs;
          // Lightweight seek for smoothness during the scroll
          updateVideoPosition(targetMs / 1000.0, shouldUpdate: false);
          update(['timeline_position']);
        }

        // Debounce: reset the timer on every scroll update
        _scrollDebounceTimer?.cancel();
        _scrollDebounceTimer = Timer(const Duration(milliseconds: 500), () {
          // Final sync after 500ms of inactivity
          if (!_isAutoScrolling) {
            updateVideoPosition(targetMs / 1000.0, shouldUpdate: true);
          }
        });
      } else if (_isUserScrolling) {
        // Handle end of scroll or fling
        _isUserScrolling = false;
        update();
      }
    });
  }

  // Initialize the audio player with the project audio.
  _initializeAudio() {
    _audioPlayer.setSource(DeviceFileSource(project.transformations.audioUrl));
    _audioPlayer.setVolume(audioVolume);
    _audioPlayer.onDurationChanged.listen((Duration d) {
      _audioDuration = d;
      update();

      // If we just picked a long audio, show the audio start selector sheet
      if (_showAudioStartOnLoad) {
        _showAudioStartOnLoad = false;
        if (canSetAudioStart) {
          Get.bottomSheet(AudioStartSheet()).then((value) {
            onAudioStartSheetClosed();
          });
          Future.delayed(Duration(milliseconds: 300), () {
            scrollToAudioStart();
          });
        }
      }
    });

    _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      _audioPlayerState = state;
      update();
    });

    _audioPlayer.onPositionChanged.listen((Duration p) {
      audioPosition = p;
      if (p.inMilliseconds > msAudioEnd) {
        pauseAudio();
      }
      update();
    });
    audioScrollController.addListener(() {
      if (audioScrollController.position.userScrollDirection !=
          ScrollDirection.idle) {
        int newPosInMilliseconds =
            ((audioScrollController.position.pixels / 12.0) * 1000).toInt();
        project.transformations.audioStart =
            Duration(milliseconds: newPosInMilliseconds);
        _audioPlayer.seek(Duration(milliseconds: newPosInMilliseconds));
      }
      update();
    });
    isAudioInitialized = true;
  }

  playAudio() {
    if (_isAudioInitialized) {
      _audioPlayer.resume();
    }
    update();
  }

  pauseAudio() {
    if (_isAudioInitialized) {
      _audioPlayer.pause();
      _audioPlayer.seek(audioStart);
    }
    update();
  }

  scrollToAudioStart() {
    audioScrollController.jumpTo(audioStart.inMilliseconds * 0.001 * 12.0);
  }

  onAudioStartSheetClosed() {
    if (isAudioPlaying) {
      pauseAudio();
      jumpToStart();
    }
  }

  _jumpTimeline(double pixels) {
    if (scrollController.hasClients) {
      _isAutoScrolling = true;
      scrollController.jumpTo(pixels);
      // Briefly ignore the next few scroll listener calls to avoid feedback loop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isAutoScrolling = false;
      });
    }
  }

  pauseVideo() {
    if (isAudioInitialized) {
      _audioPlayer.pause();
    }
    _videoController!.pause();
    update();
  }

  playVideo() {
    _isUserScrolling = false;
    // Explicitly seek to current position before playing to ensure it starts exactly at playhead
    _videoController!.seekTo(_position!);
    if (isAudioInitialized) {
      _audioPlayer.seek(Duration(
          milliseconds: _position!.inMilliseconds +
              audioStart.inMilliseconds -
              trimStart));
      _audioPlayer.resume();
    }
    _videoController!.play();
    update();
  }

  updateVideoPosition(double position, {bool shouldUpdate = true}) {
    final int targetMs = (position * 1000).toInt();
    if (targetMs == _lastSeekMs && !shouldUpdate) return;
    _lastSeekMs = targetMs;
    _position = Duration(milliseconds: targetMs);
    _lastManualSeekTime = DateTime.now();

    _videoController!.seekTo(_position!);
    if (isAudioInitialized) {
      _audioPlayer.seek(Duration(
          milliseconds: targetMs + audioStart.inMilliseconds - trimStart));
    }
    if (shouldUpdate) {
      update();
    }
  }

  setTrimStart() {
    if (_position!.inMilliseconds < trimEnd) {
      project.transformations.trimStart = _position!;
    } else {
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        translations.deniedOperationErrorTitle.tr,
        translations.setTrimStartErrorMessage.tr,
        Icons.error_outline,
      );
    }
    update();
  }

  setTrimEnd() {
    if (_position!.inMilliseconds > trimStart) {
      project.transformations.trimEnd = _position!;
    } else {
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        translations.deniedOperationErrorTitle.tr,
        translations.setTrimEndErrorMessage.tr,
        Icons.error_outline,
      );
    }
    update();
  }

  jumpBack50ms() {
    _position = Duration(milliseconds: _position!.inMilliseconds - 50);
    _lastManualSeekTime = DateTime.now();
    _videoController!.seekTo(_position!);
    scrollController.jumpTo(scrollController.position.pixels - 2.5);
    update();
  }

  jumpForward50ms() {
    _position = Duration(milliseconds: _position!.inMilliseconds + 50);
    _lastManualSeekTime = DateTime.now();
    _videoController!.seekTo(_position!);
    scrollController.jumpTo(scrollController.position.pixels + 2.5);
    update();
  }

  jumpToStart() {
    _videoController!.pause();
    _position = Duration(milliseconds: trimStart);
    _lastManualSeekTime = DateTime.now();
    _videoController!.seekTo(_position!);
    _jumpTimeline(0);
    if (isAudioInitialized) {
      _audioPlayer.seek(audioStart);
      _audioPlayer.pause();
    }
    update();
  }

  pickAudio() async {
    // If the video is playing, pause it.
    if (isVideoPlaying) {
      pauseVideo();
    }

    FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'aac', 'm4a'],
    ).then((result) {
      if (result != null) {
        project.transformations.audioUrl = result.files.single.path!;
        project.transformations.audioName = result.files.single.name;
        project.transformations.audioStart = Duration.zero;
        _showAudioStartOnLoad = true;
        _initializeAudio();
        update();
      }
    });
  }

  removeAudio() {
    if (hasAudio) {
      project.transformations.audioUrl = '';
      project.transformations.audioName = '';
      project.transformations.audioStart = Duration.zero;
      _audioPlayer.release();
      isAudioInitialized = false;
      update();
    } else {
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        translations.deniedOperationErrorTitle.tr,
        translations.noAudioToRemoveErrorMessage.tr,
        Icons.error_outline,
      );
    }
  }

  addProjectText({double? x, double? y}) {
    print('DEBUG: addProjectText called with text: $textToAdd at ($x, $y)');
    // Avoid duration to be bigger than the video duration.
    int msStartTime = _position!.inMilliseconds;
    int finalTextDuration = textDuration * 1000;

    if (msStartTime + (textDuration * 1000) > trimEnd) {
      finalTextDuration = (trimEnd - msStartTime);
    }

    TextTransformation t = TextTransformation(
      text: textToAdd,
      msDuration: finalTextDuration,
      msStartTime: msStartTime,
      x: x,
      y: y,
    );
    project.transformations.texts.add(t);

    // Set the selected text to the new text.
    selectedTextId = t.id;

    // Reset the textToAdd and textDuration variables.
    textToAdd = '';
    textDuration = 5;
    print('DEBUG: addProjectText finished, text added to list');
  }

  updateTextCoordinates(String id, double x, double y) {
    TextTransformation text =
        project.transformations.texts.firstWhere((element) => element.id == id);
    text.x = x;
    text.y = y;
    update();
  }

  deleteSelectedText() {
    if (selectedTextId != '') {
      project.transformations.texts
          .removeWhere((element) => element.id == selectedTextId);
      selectedTextId = '';
      update();
    } else {
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        translations.cannotDeleteTextErrorTitle.tr,
        translations.cannotDeleteTextErrorMessage.tr,
        Icons.error_outline,
      );
    }
  }

  updateTextFontSize(double fontSize) {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .fontSize = fontSize;
    update();
  }

  updateFontColor(Color color) {
    print('Color: 0x${color.value.toRadixString(16)}');
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .color = '0x${color.value.toRadixString(16)}';
    update();
  }

  updateBackgroundColor(Color color) {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .backgroundColor = '0x${color.value.toRadixString(16)}';
    update();
  }

  clearBackgroundColor() {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .backgroundColor = '';
    update();
  }

  updateTextPosition(TextPosition position) {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .position = position;
    update();
  }

  setTextStart() {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .msStartTime = msVideoPosition;
    update();
  }

  setTextStartAndUpdateDuration() {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .msStartTime = msVideoPosition;
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .msDuration = trimEnd - msVideoPosition;
    update();
  }

  void updateTimelineScale(double newScale) {
    // Basic scale update logic
    timelineScale = newScale.clamp(10.0, 1000.0);
    update();
  }

  void onScaleStart() {
    _baseScale = timelineScale;
    isTimelineScrollLocked = true;
    _isUserScrolling = true;

    // Capture the time at the playhead to anchor the zoom
    // or capture the time at the center of the viewport
    if (scrollController.hasClients) {
      double pixels = scrollController.offset;
      _anchoredTimeMs = (pixels / timelineScale * 1000).toInt();
    } else {
      _anchoredTimeMs = 0;
    }

    update();
  }

  int _anchoredTimeMs = 0;

  void onScaleUpdate(double scale) {
    if (!scrollController.hasClients) {
      updateTimelineScale(_baseScale * scale);
      return;
    }

    double oldScale = timelineScale;
    double newScale = (_baseScale * scale).clamp(10.0, 1000.0);

    if (oldScale == newScale) return;

    // Position of the anchored time in pixels before scaling
    double oldPixels = (_anchoredTimeMs * 0.001 * oldScale);
    // Offset from the start of the viewport
    double viewportOffset = oldPixels - scrollController.offset;

    // Update the scale
    timelineScale = newScale;

    // Position of the anchored time in pixels after scaling
    double newPixels = (_anchoredTimeMs * 0.001 * newScale);
    // New scroll offset to keep the anchored time at the same viewport position
    double newScrollOffset = newPixels - viewportOffset;

    _jumpTimeline(newScrollOffset.clamp(
        0.0,
        scrollController.position.maxScrollExtent +
            2000)); // allow some overscroll during gesture

    update();
  }

  void onScaleEnd() {
    isTimelineScrollLocked = false;
    _isUserScrolling = false;
    _anchoredTimeMs = 0;
    update();
  }

  updateTextDuration(int duration) {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .msDuration = duration;
    update();
  }

  updateSelectedTextContent(String value) {
    project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId)
        .text = value;
    update();
  }

  updateTextStartDelta(String id, int deltaMs) {
    TextTransformation text =
        project.transformations.texts.firstWhere((element) => element.id == id);
    int newStart = text.msStartTime + deltaMs;
    if (newStart < 0) newStart = 0;
    // ensure start + duration doesn't exceed video duration
    if (newStart + text.msDuration > trimEnd) {
      newStart = trimEnd - text.msDuration;
    }
    text.msStartTime = newStart;
    update();
  }

  updateTextDurationDelta(String id, int deltaMs) {
    TextTransformation text =
        project.transformations.texts.firstWhere((element) => element.id == id);
    int newDuration = text.msDuration + deltaMs;
    if (newDuration < 100) newDuration = 100; // min 100ms
    if (text.msStartTime + newDuration > trimEnd) {
      newDuration = trimEnd - text.msStartTime;
    }
    text.msDuration = newDuration;
    update();
  }

  resetCrop() {
    setCropAspectRatio(CropAspectRatio.FREE);
    cropX = 0;
    cropY = 0;
    cropWidth = videoWidth;
    cropHeight = videoHeight;
  }

  setCropAspectRatio(CropAspectRatio aspectRatio) {
    project.transformations.cropAspectRatio = aspectRatio;

    if (aspectRatio != CropAspectRatio.FREE) {
      cropX = 0;
      cropY = 0;
    }

    switch (aspectRatio) {
      case CropAspectRatio.SQUARE:
        if (isHorizontal) {
          cropWidth = videoHeight;
          cropHeight = videoHeight;
        } else {
          cropWidth = videoWidth;
          cropHeight = videoWidth;
        }
      case CropAspectRatio.RATIO_16_9:
        if (isHorizontal) {
          cropWidth = videoHeight * 16 / 9;
          cropHeight = videoHeight;
        } else {
          cropWidth = videoWidth;
          cropHeight = videoWidth * 9 / 16;
        }
      case CropAspectRatio.RATIO_9_16:
        if (isHorizontal) {
          cropWidth = videoHeight * 9 / 16;
          cropHeight = videoHeight;
        } else {
          cropWidth = videoWidth;
          cropHeight = videoWidth * 16 / 9;
        }
      case CropAspectRatio.RATIO_4_5:
        if (isHorizontal) {
          cropWidth = videoHeight * 4 / 5;
          cropHeight = videoHeight;
        } else {
          cropWidth = videoWidth;
          cropHeight = videoWidth * 5 / 4;
        }
      default:
    }
    update();
  }

  updateTopLeft(Offset offset) {
    switch (cropAspectRatio) {
      case CropAspectRatio.SQUARE:
        // Code explanation:
        // 1. The cropX is the new X position of the crop box. It is calculated by adding the offset.dx to the initial cropX.
        //    a. The clamp is used to maintain always the box inside the limits.
        //    b. The max in the minValue of the clamp is used to avoid the X going out the left side of the screen (0.0)
        //       or the top (the box cannot grow bigger if the Y is already at 0.0).
        // 2. The cropY is the new Y position of the crop box. As we are trying to maintain a squared aspect ratio, the
        //    Y is always going to depend on how much the cropX has changed over time, in a 1:1 relation.
        cropX = (offset.dx + initX)
            .clamp(max(0.0, initialCropX - initialCropY),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropY = ((cropX - initialCropX) + initialCropY)
            .clamp(0.0, initialCropHeight / scalingFactor + initialCropY)
            .toDouble();
      case CropAspectRatio.RATIO_16_9:
        cropX = (offset.dx + initX)
            .clamp(max(0.0, (initialCropX - (initialCropY * 16 / 9))),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropY = ((cropX - initialCropX) * (9 / 16) + initialCropY)
            .clamp(0.0, initialCropHeight / scalingFactor + initialCropY)
            .toDouble();
      case CropAspectRatio.RATIO_9_16:
        cropX = (offset.dx + initX)
            .clamp(max(0.0, (initialCropX - (initialCropY * 9 / 16))),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropY = ((cropX - initialCropX) * (16 / 9) + initialCropY)
            .clamp(0.0, initialCropHeight / scalingFactor + initialCropY)
            .toDouble();
      case CropAspectRatio.RATIO_4_5:
        cropX = (offset.dx + initX)
            .clamp(max(0.0, (initialCropX - (initialCropY * 4 / 5))),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropY = ((cropX - initialCropX) * (5 / 4) + initialCropY)
            .clamp(0.0, initialCropHeight / scalingFactor + initialCropY)
            .toDouble();
      case CropAspectRatio.FREE:
        cropX = (offset.dx + initX)
            .clamp(0.0, initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropY = (offset.dy + initY)
            .clamp(0.0, initialCropHeight / scalingFactor + initialCropY)
            .toDouble();
    }
    update();
  }

  updateTopRight(Offset offset) {
    switch (cropAspectRatio) {
      case CropAspectRatio.SQUARE:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(initialCropWidth + (initialCropY * scalingFactor),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropY = (initialCropWidth / scalingFactor) - cropWidth + initialCropY;
      case CropAspectRatio.RATIO_16_9:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(initialCropWidth + initialCropY * scalingFactor * (16 / 9),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropY = ((initialCropWidth / scalingFactor) - cropWidth) * (9 / 16) +
            initialCropY;
      case CropAspectRatio.RATIO_9_16:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(initialCropWidth + initialCropY * scalingFactor * (9 / 16),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropY = ((initialCropWidth / scalingFactor) - cropWidth) * (16 / 9) +
            initialCropY;
      case CropAspectRatio.RATIO_4_5:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(initialCropWidth + initialCropY * scalingFactor * (4 / 5),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropY = ((initialCropWidth / scalingFactor) - cropWidth) * (5 / 4) +
            initialCropY;
      case CropAspectRatio.FREE:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(0.0, videoWidth - cropX * scalingFactor)
            .toDouble();
        cropY = (offset.dy + initY)
            .clamp(0.0, (initialCropHeight / scalingFactor + initialCropY))
            .toDouble();
      default:
    }
  }

  updateBottomLeft(Offset offset) {
    switch (cropAspectRatio) {
      case CropAspectRatio.SQUARE:
        cropX = (offset.dx + initX)
            .clamp(
                max(
                    0.0,
                    initialCropX -
                        (videoHeight / scalingFactor -
                            (initialCropY +
                                initialCropHeight / scalingFactor))),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropHeight =
            (initialCropHeight - (cropX - initialCropX) * scalingFactor)
                .clamp(0.0, videoHeight - cropY * scalingFactor)
                .toDouble();
      case CropAspectRatio.RATIO_16_9:
        cropX = (offset.dx + initX)
            .clamp(
                max(
                    0.0,
                    initialCropX -
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            16 /
                            9),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropHeight = (initialCropHeight -
                (cropX - initialCropX) * scalingFactor * (9 / 16))
            .clamp(0.0, videoHeight - cropY * scalingFactor)
            .toDouble();
      case CropAspectRatio.RATIO_9_16:
        cropX = (offset.dx + initX)
            .clamp(
                max(
                    0.0,
                    initialCropX -
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            9 /
                            16),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropHeight = (initialCropHeight -
                (cropX - initialCropX) * scalingFactor * (16 / 9))
            .clamp(0.0, videoHeight - cropY * scalingFactor)
            .toDouble();
      case CropAspectRatio.RATIO_4_5:
        cropX = (offset.dx + initX)
            .clamp(
                max(
                    0.0,
                    initialCropX -
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            4 /
                            5),
                initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropHeight = (initialCropHeight -
                (cropX - initialCropX) * scalingFactor * (5 / 4))
            .clamp(0.0, videoHeight - cropY * scalingFactor)
            .toDouble();
      case CropAspectRatio.FREE:
        cropX = (offset.dx + initX)
            .clamp(0.0, initialCropWidth / scalingFactor + initialCropX)
            .toDouble();
        cropHeight = ((offset.dy + initY - cropY) * scalingFactor)
            .clamp(0.0, videoHeight - cropY * scalingFactor)
            .toDouble();
    }
  }

  updateBottomRight(Offset offset) {
    switch (cropAspectRatio) {
      case CropAspectRatio.SQUARE:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(
                    initialCropWidth +
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            scalingFactor,
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropHeight = cropWidth * scalingFactor;
      case CropAspectRatio.RATIO_16_9:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(
                    initialCropWidth +
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            scalingFactor *
                            (16 / 9),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropHeight = cropWidth * scalingFactor * (9 / 16);
      case CropAspectRatio.RATIO_9_16:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(
                    initialCropWidth +
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            scalingFactor *
                            (9 / 16),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropHeight = cropWidth * scalingFactor * (16 / 9);
      case CropAspectRatio.RATIO_4_5:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(
                0.0,
                min(
                    initialCropWidth +
                        (videoHeight / scalingFactor -
                                (initialCropY +
                                    initialCropHeight / scalingFactor)) *
                            scalingFactor *
                            (4 / 5),
                    videoWidth - cropX * scalingFactor))
            .toDouble();
        cropHeight = cropWidth * scalingFactor * (5 / 4);
      case CropAspectRatio.FREE:
        cropWidth = ((offset.dx + initX - cropX) * scalingFactor)
            .clamp(0.0, videoWidth - cropX * scalingFactor)
            .toDouble();
        cropHeight = ((offset.dy + initY - cropY) * scalingFactor)
            .clamp(0.0, videoHeight - cropY * scalingFactor)
            .toDouble();
      default:
    }
  }

  exportVideo() async {
    if (isVideoPlaying) {
      pauseVideo();
    }

    // Generate the FFMPEG command and navigate to the export page.
    String dateTime = DateFormat('yyyyMMdd_HH:mm:ss').format(DateTime.now());
    String outputPath = await generateOutputPath('${project.name}_$dateTime');

    // Get the font scaling factor. Video height / in app height if vertical. Video width / in app width if horizontal.
    double finalScalingFactor =
        num.parse(scalingFactor.toStringAsFixed(2)).toDouble();
    print('Font scaling factor: $scalingFactor');

    // Get the export options
    final ExportOptions exportOptions = ExportOptions(
      videoBitrate: bitrateActive ? Constants.videoBitrates[_bitrate] : '',
      videoFps: fpsActive ? Constants.videoFps[_fps] : '',
    );

    String path = project.mediaUrl;

    String command = await generateFFMPEGCommand(
      path,
      outputPath,
      exportVideoDuration,
      project.transformations,
      videoWidth,
      videoHeight,
      finalScalingFactor,
      exportOptions,
    );

    void printWrapped(String text) => RegExp('.{1,800}')
        .allMatches(text)
        .map((m) => m.group(0))
        .forEach(print);
    // Log the command to be executed and close the bottom sheet
    printWrapped('Will execute : ffmpeg $command');
    Get.back();

    Get.toNamed(
      Routes.EXPORT,
      arguments: {
        'command': command,
        'outputPath': outputPath,
        'videoDuration': afterExportVideoDuration
      },
    );
  }
}
