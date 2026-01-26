import 'package:flutter/material.dart';
import 'package:shital_video_editor/controllers/editor_controller.dart';
import 'package:shital_video_editor/shared/widgets/colored_icon_button.dart';
import 'package:get/get.dart';
import 'package:shital_video_editor/shared/translations/translation_keys.dart'
    as translations;

class AddTextDialog extends StatelessWidget {
  final double? x;
  final double? y;

  const AddTextDialog({super.key, this.x, this.y});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<EditorController>(
      builder: (_) {
        return GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Dialog(
            alignment: Alignment.center,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24.0)),
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(translations.addTextDialogTitle.tr,
                        style: Theme.of(context).textTheme.titleLarge),
                    SizedBox(height: 24.0),
                    Text(
                      translations.addTextDialogMessage.tr,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: 16.0),
                    TextField(
                      onChanged: (value) => _.textToAdd = value,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        labelText: translations.addTextDialogLabel.tr,
                        labelStyle: Theme.of(context).textTheme.bodySmall,
                        suffixIcon: IconButton(
                          onPressed: () {
                            _.textToAdd = '';
                          },
                          icon: Icon(Icons.cancel_outlined),
                          splashRadius: 20.0,
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Text(translations.addTextDialogDuration.tr,
                        style: Theme.of(context).textTheme.titleSmall),
                    SizedBox(height: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ColoredIconButton(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(Get.isDarkMode ? 1 : 0.2),
                          icon: Icons.remove,
                          onPressed: () {
                            _.textDuration > 1
                                ? _.textDuration -= 1
                                : _.textDuration = 1;
                          },
                        ),
                        SizedBox(width: 8.0),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 2.0),
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Text('${_.textDuration}s',
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        ColoredIconButton(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(Get.isDarkMode ? 1 : 0.2),
                          icon: Icons.add,
                          onPressed: () {
                            _.textDuration += 1;
                          },
                        )
                      ],
                    ),
                    SizedBox(height: 20.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            print('DEBUG: AddTextDialog Cancel pressed');
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.background,
                            elevation: 0.0,
                            padding: EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 14.0),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.0)),
                          ),
                          child: Text(translations.addTextDialogCancel.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(fontWeight: FontWeight.bold)),
                        ),
                        SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: _.textToAdd != ''
                              ? () {
                                  print('DEBUG: AddTextDialog Save pressed');
                                  _.addProjectText(x: x, y: y);
                                  print(
                                      'DEBUG: calling Navigator.pop in AddTextDialog');
                                  Navigator.of(context).pop();
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            disabledBackgroundColor:
                                Theme.of(context).disabledColor,
                            disabledForegroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: EdgeInsets.all(16),
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                  color: _.textToAdd == ''
                                      ? Theme.of(context).disabledColor
                                      : Theme.of(context).colorScheme.primary,
                                  width: 2.0),
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                          ),
                          child: Text(translations.addTextDialogSave.tr,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                      fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
