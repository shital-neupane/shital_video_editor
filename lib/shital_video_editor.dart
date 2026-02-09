import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shital_video_editor/routes/app_pages.dart';
import 'package:shital_video_editor/shared/core/themes.dart';
import 'package:shital_video_editor/shared/translations/messages.dart';
import 'package:shital_video_editor/shared/logger_service.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await logger.init();
  logger.info('Application starting...');

  runApp(ShitalVE());
}

class ShitalVE extends StatefulWidget {
  const ShitalVE({
    super.key,
    this.initialVideo,
  });

  final String? initialVideo;

  @override
  State<ShitalVE> createState() => _ShitalVEState();
}

class _ShitalVEState extends State<ShitalVE> {
  bool loaded = false;
  bool _shouldClose = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialVideo != null && widget.initialVideo!.isNotEmpty) {
      debugPrint(
          "SEARCH INITIAL VIDEO was not null in main on init runni save");
      _initialize();
    } else {
      _shouldClose = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
    }
  }

  Future<void> _initialize() async {
    await logger.init();
    logger.info(
        'ShitalVE widget initializing with video: ${widget.initialVideo}');

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('initialVideo', widget.initialVideo!);
    print("SEARCH ADDED INITIAL VIDEO TO PREF");

    if (mounted) {
      setState(() {
        loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    if (_shouldClose) {
      return const SizedBox.shrink();
    }

    return loaded
        ? GetMaterialApp(
            translations: Messages(),
            locale: const Locale('en'),
            fallbackLocale: const Locale('en', 'US'),
            getPages: AppPages.routes,
            initialRoute: AppPages.INITIAL,
            themeMode: ThemeMode.dark,
            theme: appThemeData,
            darkTheme: appThemeDataDark,
            debugShowCheckedModeBanner: false,
          )
        : const Center(child: CircularProgressIndicator());
  }
}
