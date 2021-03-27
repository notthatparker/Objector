import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
//import 'package:image_picker_for_web/image_picker_for_web.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

const String ssd = "SSD MobileNet";
const String yolo = "Tiny YOLOv2";

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Objector',
      theme: ThemeData(
          primarySwatch: Colors.amber, backgroundColor: Colors.black87),
      home: TfliteHome(),
    );
  }
}

class TfliteHome extends StatefulWidget {
  TfliteHome({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _TfliteHomeState createState() => _TfliteHomeState();
}

class _TfliteHomeState extends State<TfliteHome> {
  String _model = ssd;
  File _image;
  // final _picker = ImagePicker();
  double _imageWidth;
  double _imageHeight;
  bool _busy = false;
  List _recog;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _busy = true;
    loadModel().then((val) {
      setState(() {
        _busy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yolo) {
        res = await Tflite.loadModel(
          model: "assets/tflite/yolov2_tiny.tflite",
          labels: "assets/tflite/yolov2_tiny.txt",
        );
        print("sucs yolo");
      } else {
        res = await Tflite.loadModel(
          model: "assets/tflite/ssd_mobilenet.tflite",
          labels: "assets/tflite/ssd_mobilenet.txt",
        );
        print("sucs ssd");
      }

      print(res);
    } on PlatformException {
      print("Failed to load the model");
    }
  }

  Future selectImage() async {
    final PickedFile imagefio =
        await _picker.getImage(source: ImageSource.gallery);
    if (imagefio == null) {
      return;
    } //since update we changed the way we take the photo

    File image = File(imagefio
        .path); //since in tutorial we used file extension we will use this to keep close to the instrct

    if (image == null) return;
    setState(() {
      _busy = true;
    });
    predictImage(image);
    //File file = File(image.path);

    // final pcikedImage = await picker.getImage
  }

  Future selectImageCamera() async {
    final PickedFile imagefio =
        await _picker.getImage(source: ImageSource.camera);
    if (imagefio == null) {
      return;
    } //since update we changed the way we take the photo

    File image = File(imagefio
        .path); //since in tutorial we used file extension we will use this to keep close to the instrct

    if (image == null) return;
    setState(() {
      _busy = true;
    });
    predictImage(image);
    //File file = File(image.path);

    // final pcikedImage = await picker.getImage
  }

  predictImage(File image) async {
    if (image == null) return; //if no image return
    if (_model == yolo) {
      await yolov2Tiny(image); // if we selected yolo
      print("done waiting yolo");
    } else {
      await ssdMobileNet(image); // if we selected ssd
      print("done waiting mobnet");
    }

    FileImage(image)
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      setState(() {
        _imageWidth = info.image.width.toDouble();
        _imageHeight = info.image.height.toDouble();
      });
    }));

    setState(() {
      _image = image;
      _busy = false;
    });
  }

  Future yolov2Tiny(File image) async {
    var recog = await Tflite.detectObjectOnImage(
        path: image.path,
        model: 'YOLO',
        threshold: 0.5,
        imageMean: 127.5,
        imageStd: 255.0,
        numResultsPerClass: 10);

    setState(() {
      _recog = recog;
    });
  }

  Future ssdMobileNet(File image) async {
    var recogi = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 5,
      threshold: 0.51,
      imageMean: 128.5,
      imageStd: 255.0,
    );

    setState(() {
      _recog = recogi;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recog == null) return [];
    if (_imageWidth == null || _imageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _imageHeight / _imageHeight * screen.width;

    return _recog.map((re) {
      return Positioned(
        left: re["rect"]["x"] * factorX,
        top: re["rect"]["y"] * factorY,
        width: re["rect"]["w"] * factorX,
        height: re["rect"]["h"] * factorY,
        child: Container(
            decoration: BoxDecoration(
                border: Border.all(
              color: Colors.amber,
              width: 5,
            )),
            child: Text(
              "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}",
              style: TextStyle(
                background: Paint()..color = Colors.amber,
                color: Colors.white,
                fontSize: 16,
              ),
            )),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    List<Widget> stackChildren = [];
    stackChildren.add(Positioned(
      top: 0.0,
      left: 0.0,
      width: size.width,
      child: _image == null
          ? Center(
              child: Image(
              image: NetworkImage('https://i.imgur.com/dGANqKX.png'),
            ))
          : Image.file(_image),
    ));

    stackChildren.addAll(renderBoxes(size));
    if (_busy) {
      stackChildren.add(Center(
        child: CircularProgressIndicator(),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text("Objector"),
      ),
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(12),
        ),
        height: 80,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                "Simple Object Detection App",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
              )
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
          child: Icon(Icons.image),
          tooltip: "Pick Image from gallery",
          onPressed: () {
            selectImage();
            print(_recog.map);
          }),
      body: Container(
        child: Stack(
          children: stackChildren,
        ),
      ),
    );
  }
}
