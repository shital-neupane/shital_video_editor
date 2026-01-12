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
            ? _audioTimeline(context, _.videoDurationMs / 1000 * 50.0)
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
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8.0, 0.0, 16.0, 0.0),
                    child: Row(
                      children: [
                        Icon(
                          _.hasAudio ? Icons.audiotrack : Icons.add,
                          color: CustomColors.audioTimeline,
                        ),
                        SizedBox(width: 4.0),
                        Expanded(
                          child: Text(
                            _.hasAudio
                                ? _.audioName
                                : translations.audioTimelineAddAudio.tr,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(color: CustomColors.audioTimeline),
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
