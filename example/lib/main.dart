import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:pedantic/pedantic.dart';

late List<CameraDescription> cameras;

void main() async {
  // Fetch the available cameras before initializing the app.
  try {
    WidgetsFlutterBinding.ensureInitialized();
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Camera error: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZXing Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  CameraController? _controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);

    var camera = cameras.first;
    _onCameraSelected(camera);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    var controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _onCameraSelected(controller.description);
    }
  }

  void _onCameraSelected(CameraDescription cameraDescription) async {
    var controller = _controller;
    if (controller != null) {
      await controller.dispose();
    }
    controller = _controller = CameraController(
      cameraDescription,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    // If the controller is updated then update the UI.
    controller.addListener(() {
      var controller = _controller!;
      if (mounted) setState(() {});
      if (controller.value.hasError) {
        print('Camera error ${controller.value.errorDescription}');
      }
    });

    unawaited(controller.startImageStream((image) {
      print('image available ${image.width}x${image.height}');
    }));
  }

  @override
  Widget build(BuildContext context) {
    var controller = _controller;
    return Scaffold(
      appBar: AppBar(
        title: Text('ZXing Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (controller != null)
              SizedBox(
                height: 500,
                child: CameraPreview(controller),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }
}
