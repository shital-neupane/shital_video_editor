import 'package:get/get.dart';
import 'package:shital_video_editor/controllers/export_controller.dart';

class ExportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ExportController>(() {
      final args = Get.arguments;
      if (args == null) {
        throw Exception('ExportBinding: Get.arguments is null');
      }
      return ExportController(
        command: args['command'],
        outputPath: args['outputPath'],
        videoDuration: args['videoDuration'],
      );
    });
  }
}
