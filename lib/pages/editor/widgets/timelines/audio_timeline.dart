import 'package:flutter/material.dart';
import 'package:shital_video_editor/controllers/editor_controller.dart';
import 'package:shital_video_editor/shared/core/colors.dart';
import 'package:shital_video_editor/shared/core/constants.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/translations/translation_keys.dart'
    as translations;

class AudioTimeline extends StatelessWidget {
  const AudioTimeline({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditorController>(
      builder: (_) {
        return _.isVideoInitialized
            ? _audioTimeline(
                context, (_.trimEnd - _.trimStart) / 1000 * _.timelineScale)
            : SizedBox.shrink();
      },
    );
  }

  _audioTimeline(BuildContext context, double width) {
    return GetBuilder<EditorController>(
      builder: (_) {
        return Container(
          color: Color(0xFF1A1A1A), // Dark grey background
          child: Row(
            children: [
              SizedBox(width: MediaQuery.of(context).size.width * 0.5),
              InkWell(
                onTap: () {
                  // Open the audio picker
                  if (!_.hasAudio) {
                    _.pickAudio();
                  }

                  // If there is an audio, navigate to the audio edit options. Clear selected text
                  if (_.selectedOptions != SelectedOptions.AUDIO) {
                    _.selectedOptions = SelectedOptions.AUDIO;
                    _.selectedTextId = '';
                  }
                },
                child: Container(
                  width: width,
                  height: 50.0,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(
                      color: const Color.fromARGB(0, 255, 255, 255),
                      width: 2.0,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.0),
                    child: Stack(
                      children: [
                        if (_.hasAudio)
                          Positioned.fill(
                            child: CustomPaint(
                              painter: AudioWavePainter(
                                color:
                                    _.selectedOptions == SelectedOptions.AUDIO
                                        ? Colors.white.withOpacity(0.8)
                                        : CustomColors.audioTimeline
                                            .withOpacity(0.2),
                                msTrimStart: _.trimStart,
                                msTrimEnd: _.trimEnd,
                                timelineScale: _.timelineScale,
                              ),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(8.0, 0.0, 16.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Icon(
                                  _.hasAudio ? Icons.audiotrack : Icons.add,
                                  color: CustomColors.audioTimeline,
                                ),
                                SizedBox(width: 4.0),
                                Flexible(
                                  child: Text(
                                    _.hasAudio
                                        ? _.audioName
                                        : translations.audioTimelineAddAudio.tr,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall!
                                        .copyWith(
                                      color: CustomColors.audioTimeline,
                                      shadows: [
                                        Shadow(
                                          blurRadius: 3.0,
                                          color: Colors.black,
                                          offset: Offset(1.0, 1.0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: MediaQuery.of(context).size.width * 0.5),
            ],
          ),
        );
      },
    );
  }
}

class AudioWavePainter extends CustomPainter {
  final Color color;
  final int msTrimStart;
  final int msTrimEnd;
  final double timelineScale;

  AudioWavePainter({
    required this.color,
    required this.msTrimStart,
    required this.msTrimEnd,
    required this.timelineScale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final double barGap = 6.0;
    final int barCount = (size.width / barGap).ceil();

    final double trimStartPx = (msTrimStart / 1000) * timelineScale;
    final double trimEndPx = (msTrimEnd / 1000) * timelineScale;

    canvas.save();
    canvas.translate(-trimStartPx, 0);

    for (int i = 0; i < barCount; i++) {
      final double x = i * barGap;

      // Only draw if within trim range
      if (x < trimStartPx || x > trimEndPx) continue;

      final double h = i % 2 == 0 ? size.height * 0.7 : size.height * 0.4;
      final double y = (size.height - h) / 2;

      canvas.drawLine(
        Offset(x, y),
        Offset(x, y + h),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant AudioWavePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.msTrimStart != msTrimStart ||
      oldDelegate.msTrimEnd != msTrimEnd ||
      oldDelegate.timelineScale != timelineScale;
}
