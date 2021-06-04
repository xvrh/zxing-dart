import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:zxing2/qrcode.dart';
import 'package:zxing2_example/decode.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController controller;
  Result? _result;

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});

      controller.startImageStream((image) {
        //var decoded = decode(image);
        //if (decoded != _result) {
        //  setState(() {
        //    _result = decoded;
        //  });
        //}
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return Container();
    }
    var result = _result;
    return MaterialApp(
      home: Scaffold(
          body: Column(
        children: [
          Expanded(child: CameraPreview(controller)),
          if (result != null)
            Text('Scanned: ${result.text}')
          else
            Text('Nothing scanned'),
          SizedBox(height: 150),
        ],
      )),
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
