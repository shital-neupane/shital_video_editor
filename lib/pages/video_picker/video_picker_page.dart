import 'package:flutter/material.dart';
import 'package:shital_video_editor/models/project.dart';
import 'package:shital_video_editor/models/media_transformations.dart';
import 'package:shital_video_editor/routes/app_pages.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class VideoPickerPage extends StatefulWidget {
  const VideoPickerPage({super.key});


   static Future<String> _getInitialVideo() async {
    Future.delayed(Duration(seconds: 1));
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('initialVideo') ?? '';
  }

  @override
  State<VideoPickerPage> createState() => _VideoPickerPageState();
}

class _VideoPickerPageState extends State<VideoPickerPage> {
  final ImagePicker _picker = ImagePicker();
  bool initVidChecked = false;
  bool saveChecked = false;




  @override
  void initState(){
    _checkForSavedVideo(context);  
    _checkForInitialVideo(context);
    super.initState();
  }

   Future<void> _checkForInitialVideo(BuildContext context) async {
    final String videoPath = await VideoPickerPage._getInitialVideo();
    print("SEARCH -ran upto _check for initvideo in video picker page");
    if (videoPath.isNotEmpty && File(videoPath).existsSync()) {
      // Only navigate if the file still exists
      // if (mounted) {
      print("there was a initial video found SEARCH");
        _navigateToEditor(context, videoPath);
      // }
    }
    setState(() {
      initVidChecked = true;
    });
  }

   Future<String> _getFinalVideo() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('editedVideo') ?? '';
  }

    Future<void> _checkForSavedVideo(BuildContext context) async {
    print("search checking edited video in video picker init");
    final String videoPath = await _getFinalVideo();
    if (videoPath.isNotEmpty && File(videoPath).existsSync()) {
     
      // if (mounted) {
         print('search this popped off from video picker $videoPath');
         Navigator.pop(context);
      // }
    }else{print("search not found final video in picker");}

      setState(() {
        saveChecked = true;
      });
    
  }

  // Future<void> _pickVideoFromGallery(BuildContext context) async {
  //   final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
  //   if (video != null) {
  //     _navigateToEditor(context, video.path);
  //   }
  // }

  // Future<void> _pickVideoFromCamera(BuildContext context) async {
  //   final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
  //   if (video != null) {
  //     _navigateToEditor(context, video.path);
  //   }
  // }

  void _navigateToEditor(BuildContext context, String videoPath) {
    // Create a basic project with the video path
    final project = Project(
      name: 'Video Project',
      mediaUrl: videoPath,
      // transformations: MediaTransformations(),
    );

    Get.offAndToNamed(Routes.EDITOR, arguments: project);
  }

  @override
  Widget build(BuildContext context) {
    

    return initVidChecked && saveChecked? Scaffold(
      appBar: AppBar(
        title: Text('Video Editor'),
        centerTitle: true,
      ),
      body: Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(),),)
      
      
      
      // Padding(
      //   padding: const EdgeInsets.all(24.0),
      //   child: Column(
      //     mainAxisAlignment: MainAxisAlignment.center,
      //     children: [
      //       Icon(
      //         Icons.video_file,
      //         size: 100,
      //         color: Theme.of(context).primaryColor,
      //       ),
      //       SizedBox(height: 32),
      //       Text(
      //         'Select a video to edit',
      //         style: Theme.of(context).textTheme.headlineSmall,
      //         textAlign: TextAlign.center,
      //       ),
      //       SizedBox(height: 16),
      //       Text(
      //         'Choose a video from your device to start editing',
      //         style: Theme.of(context).textTheme.bodyMedium,
      //         textAlign: TextAlign.center,
      //       ),
      //       SizedBox(height: 48),
      //       ElevatedButton.icon(
      //         onPressed: () => _pickVideoFromGallery(context),
      //         icon: Icon(Icons.video_library),
      //         label: Text('Choose from Gallery'),
      //         style: ElevatedButton.styleFrom(
      //           padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      //           backgroundColor: Theme.of(context).primaryColorLight,
      //           foregroundColor: Colors.white,
      //           shape: RoundedRectangleBorder(
      //             borderRadius: BorderRadius.circular(12),
      //           ),
      //         ),
      //       ),
      //       SizedBox(height: 16),
      //       ElevatedButton.icon(
      //         onPressed: () => _pickVideoFromCamera(context),
      //         icon: Icon(Icons.camera_alt),
      //         label: Text('Record New Video'),
      //         style: ElevatedButton.styleFrom(
      //           padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      //           backgroundColor: Theme.of(context).primaryColor,
      //           foregroundColor: Colors.white,
      //           shape: RoundedRectangleBorder(
      //             borderRadius: BorderRadius.circular(12),
      //           ),
      //         ),
      //       ),
      //     ],
      //   ),
      // ),
    ):
      Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(),));
    
  }
}