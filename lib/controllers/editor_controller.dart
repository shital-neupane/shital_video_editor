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
import 'package:shital_video_editor/shared/logger_service.dart';
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

  static const int maxDurationMs = 90000; // 1 min 30 sec

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

  String get videoPositionString =>
      formatTime((_position!.inMilliseconds - trimStart) ~/ 1000);
  String get videoDurationString => isVideoInitialized
      ? formatTime(afterExportVideoDuration ~/ 1000)
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
    logger.debug('EditorController onInit started');
    super.onInit();

    // Initialize the video player controller if the project has a video.
    await _initializeVideoController();

    // Initialize the audio player if the project has audio.
    if (hasAudio) {
      _initializeAudio();
    }
    logger.debug('EditorController onInit completed');
  }

  @override
  void onClose() {
    logger.debug('EditorController onClose called');
    super.onClose();
    // Dispose of the video player controller when the editor is closed.
    _videoController?.dispose();
    _audioPlayer.dispose();
    _videoController = null;
    logger.debug('EditorController onClose completed');
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

        // If the position is past the trim end, pause and jump to start (if not in trim mode).
        if (_position!.inMilliseconds >= trimEnd &&
            selectedOptions != SelectedOptions.TRIM &&
            isVideoPlaying) {
          pauseVideo();
          _videoController!.seekTo(Duration(milliseconds: trimEnd));
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
    // Check if new trim start would result in duration > maxDurationMs
    if (trimEnd - _position!.inMilliseconds > maxDurationMs) {
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        translations.deniedOperationErrorTitle.tr,
        "Video duration cannot exceed 1 min 30 sec", // You might want to add a translation key for this
        Icons.error_outline,
      );
      return;
    }

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
    // Check if new trim end would result in duration > maxDurationMs
    if (_position!.inMilliseconds - trimStart > maxDurationMs) {
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        translations.deniedOperationErrorTitle.tr,
        "Video duration cannot exceed 1 min 30 sec",
        Icons.error_outline,
      );
      return;
    }

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
    logger.debug('addProjectText called with text: $textToAdd at ($x, $y)');
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
      x: x ?? 0.4,
      y: y ?? 0.8,
    );
    project.transformations.texts.add(t);

    // Set the selected text to the new text.
    selectedTextId = t.id;

    // Reset the textToAdd and textDuration variables.
    textToAdd = '';
    textDuration = 5;
    logger.debug('addProjectText finished, text added to list');
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
    logger.debug('Color: 0x${color.value.toRadixString(16)}');
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
    TextTransformation text = project.transformations.texts
        .firstWhere((element) => element.id == selectedTextId);
    text.position = position;

    switch (position) {
      case TextPosition.TL:
        text.x = 0.1;
        text.y = 0.1;
        break;
      case TextPosition.TC:
        text.x = 0.5;
        text.y = 0.1;
        break;
      case TextPosition.TR:
        text.x = 0.9;
        text.y = 0.1;
        break;
      case TextPosition.ML:
        text.x = 0.1;
        text.y = 0.5;
        break;
      case TextPosition.MC:
        text.x = 0.5;
        text.y = 0.5;
        break;
      case TextPosition.MR:
        text.x = 0.9;
        text.y = 0.5;
        break;
      case TextPosition.BL:
        text.x = 0.1;
        text.y = 0.8;
        break;
      case TextPosition.BC:
        text.x = 0.5;
        text.y = 0.8;
        break;
      case TextPosition.BR:
        text.x = 0.9;
        text.y = 0.8;
        break;
    }
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

  // Focal point for gesture-centered zooming
  double _focalPointX = 0.0;
  int _anchoredTimeMs = 0;
  double _lastScale = 1.0;

  void onScaleStart(ScaleStartDetails details) {
    // Always capture the focal point, even for potential two-finger gestures
    _baseScale = timelineScale;
    _lastScale = 1.0;
    _focalPointX = details.localFocalPoint.dx;

    if (details.pointerCount >= 2) {
      isTimelineScrollLocked = true;
      _isUserScrolling = true;
    }

    // Calculate the anchored time based on the focal point position
    if (scrollController.hasClients) {
      // Calculate the time at the focal point (not at the start of viewport)
      double viewportWidth = Get.width;
      double focalOffsetFromCenter = _focalPointX - (viewportWidth / 2);
      double pixelsAtFocalPoint =
          scrollController.offset + focalOffsetFromCenter;
      _anchoredTimeMs = (pixelsAtFocalPoint / timelineScale * 1000).toInt();
      if (_anchoredTimeMs < 0) _anchoredTimeMs = 0;
    } else {
      _anchoredTimeMs = 0;
    }

    update();
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    // Handle transition from one finger to two fingers mid-gesture
    if (details.pointerCount >= 2 && !isTimelineScrollLocked) {
      _baseScale = timelineScale / details.scale;
      _lastScale = details.scale;
      isTimelineScrollLocked = true;
      _isUserScrolling = true;
      _focalPointX = details.localFocalPoint.dx;

      if (scrollController.hasClients) {
        double viewportWidth = Get.width;
        double focalOffsetFromCenter = _focalPointX - (viewportWidth / 2);
        double pixelsAtFocalPoint =
            scrollController.offset + focalOffsetFromCenter;
        _anchoredTimeMs = (pixelsAtFocalPoint / timelineScale * 1000).toInt();
        if (_anchoredTimeMs < 0) _anchoredTimeMs = 0;
      } else {
        _anchoredTimeMs = 0;
      }
      update();
      return;
    }

    if (!isTimelineScrollLocked) return;
    if (details.pointerCount < 2) return;

    // Use incremental scaling for smoother updates
    double scaleDelta = details.scale / _lastScale;
    _lastScale = details.scale;

    // Apply an incremental scale with smoothing factor
    // This makes both fast and slow gestures feel responsive
    double smoothingFactor = 1.0; // Direct mapping for responsiveness
    double targetScale =
        timelineScale * (1.0 + (scaleDelta - 1.0) * smoothingFactor);
    double newScale = targetScale.clamp(10.0, 1000.0);

    if ((newScale - timelineScale).abs() < 0.01) return;

    if (!scrollController.hasClients) {
      timelineScale = newScale;
      update();
      return;
    }

    double oldScale = timelineScale;

    // Calculate focal point relative to the center of the viewport
    double viewportWidth = Get.width;
    double focalOffsetFromCenter =
        details.localFocalPoint.dx - (viewportWidth / 2);

    // Calculate the time position at the focal point before scaling
    double pixelsAtFocalPoint = scrollController.offset + focalOffsetFromCenter;
    double timeAtFocalPoint = pixelsAtFocalPoint / oldScale * 1000;

    // Update the scale
    timelineScale = newScale;

    // Calculate where the same time should be after scaling
    double newPixelsAtFocalPoint = timeAtFocalPoint / 1000 * newScale;

    // Adjust scroll to keep the focal point stationary
    double newScrollOffset = newPixelsAtFocalPoint - focalOffsetFromCenter;

    double maxScroll = scrollController.position.maxScrollExtent + 2000;
    _jumpTimeline(newScrollOffset.clamp(0.0, maxScroll));

    update();
  }

  void onScaleEnd(ScaleEndDetails details) {
    isTimelineScrollLocked = false;
    _isUserScrolling = false;
    _anchoredTimeMs = 0;
    _lastScale = 1.0;
    _focalPointX = 0.0;
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
    logger.info('EXPORT: Starting exportVideo process');
    if (isVideoPlaying) {
      logger.debug('EXPORT: Video is playing, pausing it');
      pauseVideo();
    }

    try {
      // Generate the FFMPEG command and navigate to the export page.
      // Use underscores instead of colons - colons are illegal in Android file paths
      String dateTime = DateFormat('yyyyMMdd_HH_mm_ss').format(DateTime.now());
      logger.debug('EXPORT: Current timestamp for filename: $dateTime');

      String outputName = '${project.name}_$dateTime';
      logger.debug('EXPORT: Generating output path for name: $outputName');
      String outputPath = await generateOutputPath(outputName);
      logger.info('EXPORT: Output path generated: $outputPath');

      // Get the font scaling factor. Video height / in app height if vertical. Video width / in app width if horizontal.
      double finalScalingFactor =
          num.parse(scalingFactor.toStringAsFixed(2)).toDouble();
      logger.debug('EXPORT: Scaled factor calculated: $finalScalingFactor');

      // Get the export options
      final ExportOptions exportOptions = ExportOptions(
        videoBitrate: bitrateActive ? Constants.videoBitrates[_bitrate] : '',
        videoFps: fpsActive ? Constants.videoFps[_fps] : '',
      );
      logger.debug(
          'EXPORT: Export options: FPS=${exportOptions.videoFps}, Bitrate=${exportOptions.videoBitrate}');

      String path = project.mediaUrl;
      logger.debug('EXPORT: Project media URL: $path');

      logger.info('EXPORT: Generating FFMPEG command...');
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
      logger.info('EXPORT: FFMPEG command generated successfully');
      printWrapped('Will execute : ffmpeg $command');

      logger.debug('EXPORT: Closing export bottom sheet');

      // Close the export bottom sheet
      // Get.back();

      logger.info('EXPORT: Navigating to EXPORT page +1 tick');
      try {
        Get.toNamed(
          Routes.EXPORT,
          arguments: {
            'command': command,
            'outputPath': outputPath,
            'videoDuration': afterExportVideoDuration
          },
        );
      } catch (e, stackTrace) {
        logger.info(
            'EXPORT: Navigation didnot gothrough to named $e $stackTrace ');
        showSnackbar(
          Theme.of(Get.context!).colorScheme.error,
          "Export Failed",
          "An error occurred while preparing the export: $e",
          Icons.error_outline,
        );
      }
    } catch (e, stackTrace) {
      logger.error('EXPORT: CRASH in exportVideo: $e');
      logger.error('EXPORT: StackTrace: $stackTrace');
      showSnackbar(
        Theme.of(Get.context!).colorScheme.error,
        "Export Failed",
        "An error occurred while preparing the export: $e",
        Icons.error_outline,
      );
    }
  }
}
