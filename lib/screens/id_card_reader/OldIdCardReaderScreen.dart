import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../patients/AddPatientScreen.dart';
import 'package:new_swapinfi/providers/storage/secure_storage_service.dart'
    as SecureStorageProvider;

class OldIdCardReaderScreen extends StatefulWidget {
  final SecureStorageProvider.SecureStorageService secureStorageService;

  OldIdCardReaderScreen({required this.secureStorageService});
  @override
  _OldIdCardReaderScreenState createState() => _OldIdCardReaderScreenState();
}

class _OldIdCardReaderScreenState extends State<OldIdCardReaderScreen> {
  CameraController? _controller;
  late List<CameraDescription> cameras;
  final TextRecognizer _textRecognizer = TextRecognizer();
  bool _isProcessing = false;
  bool _isCardValid = false;
  String recognizedText = "";
  Map<String, String> extractedData = {};
  final Map<String, bool> fieldsFound = {
    "Nom": false,
    "Prénom": false,
    "Sexe": false,
    "Nationalité": false,
    "Date de naissance": false,
    "N° Registre national": false,
    "N° Carte": false,
    "Expire le": false,
  };

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(cameras[0], ResolutionPreset.high);
    await _controller?.initialize();
    if (!mounted) return;
    setState(() {});
    _controller?.startImageStream(_processCameraImage);
  }

  @override
  void dispose() {
    _controller?.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;

    _isProcessing = true;
    try {
      if (_controller == null || !_controller!.value.isInitialized) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final inputImage = _convertCameraImage(
          image, _controller!.description.sensorOrientation);
      final RecognizedText recognizedTextResult =
          await _textRecognizer.processImage(inputImage);

      if (!mounted) return; // Check if the widget is still mounted
      if (mounted) {
        setState(() {
          recognizedText = recognizedTextResult.text;
        });
      }

      // Extraction logic for ID card information
      _extractData(recognizedTextResult.text);

      // Check if all required fields have been found
      if (_isCardValid) {
        // await _waitForAnimation();
        // _controller?.stopImageStream();
        // _controller?.dispose();
        // _controller = null; // Ensuring the controller is null after disposal
        // Navigator.pushReplacement(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => AddPatientScreen(
        //       extractedData: extractedData,
        //       secureStorageService: widget.secureStorageService,
        //     ),
        //   ),
        // );
      }
    } catch (e) {
      // print('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  InputImage _convertCameraImage(CameraImage image, int rotation) {
    final WriteBuffer allBytes = WriteBuffer();
    image.planes.forEach((Plane plane) {
      allBytes.putUint8List(plane.bytes);
    });
    final Uint8List bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final InputImageRotation inputImageRotation =
        InputImageRotationValue.fromRawValue(rotation) ??
            InputImageRotation.rotation0deg;
    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw) ??
            InputImageFormat.nv21;

    final List<InputImageMetadata> planeData = image.planes.map(
      (Plane plane) {
        return InputImageMetadata(
            size: imageSize,
            rotation: inputImageRotation,
            format: inputImageFormat,
            bytesPerRow: plane.bytesPerRow);
      },
    ).toList();

    final InputImageMetadata inputImageData = InputImageMetadata(
      size: imageSize,
      rotation: inputImageRotation,
      format: inputImageFormat,
      bytesPerRow: planeData[0].bytesPerRow,
    );

    return InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
  }

  void _extractData(String text) {
    final List<String> ignoreList = [
      'belg',
      'carte d\'identite',
      'identiteitskaart',
      'identitetskaart',
      'kaart',
      'personalausweis',
      'identity card',
      'given names',
      'given ames',
      'name',
      'sex',
      'belgiể',
      'given',
      'prénoms',
      'personalausies',
    ];

    List<String> lines =
        text.split('\n').map((line) => line.trim().toLowerCase()).toList();

    // Remove lines that are in the ignore list
    lines = lines.where((line) => !ignoreList.contains(line)).toList();

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.contains('nom') &&
          !fieldsFound["Nom"]! &&
          !line.contains('prenom')) {
        String nextLine = "";
        try {
          nextLine = lines[i + 1].trim();
        } catch (e) {
          print('Error accessing next line: $e');
          continue;
        }

        if (!ignoreList.contains(nextLine) &&
            !nextLine.contains('/') &&
            !nextLine.toLowerCase().contains('name') &&
            (extractedData['Prénom'] == null ||
                extractedData['Prénom']?.toLowerCase() != nextLine) &&
            (extractedData['Autres prénoms'] == null ||
                extractedData['Autres prénoms']?.toLowerCase() != nextLine)) {
          // Vérification supplémentaire pour s'assurer que le nom est correct
          bool isName = true;
          for (int j = 0; j < ignoreList.length; j++) {
            if (nextLine.toLowerCase().contains(ignoreList[j])) {
              isName = false;
              break;
            }
          }

          if (isName &&
              nextLine.length > 2 &&
              !RegExp(r'\d').hasMatch(nextLine)) {
            extractedData['Nom'] = toTitleCase(nextLine);
            print('Nom: $nextLine');
            fieldsFound["Nom"] = true;
            break; // Exit loop after finding the name
          }
        }
      }
    }
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (fieldsFound["Nom"]! &&
          !fieldsFound["Prénom"]! &&
          line.contains(extractedData['Nom']!.toLowerCase().substring(0, 2))) {
        String nextLine = lines[i + 1].trim();
        print(!ignoreList.contains(nextLine));
        if (!ignoreList.contains(nextLine) &&
            !nextLine.contains('/') &&
            !nextLine.toLowerCase().contains('given names') &&
            (extractedData['Nom'] == null ||
                extractedData['Nom']?.toLowerCase() != nextLine)) {
          // Séparer la ligne en mots
          List<String> names = nextLine.split(' ');
          if (names.isNotEmpty &&
              names[0].length > 2 &&
              !RegExp(r'\d').hasMatch(names[0])) {
            // Enregistrer le premier mot dans 'Prénom'
            extractedData['Prénom'] = toTitleCase(names[0]);
            print('Prénom: ${names[0]}');
            // Enregistrer le reste dans 'Autres prénoms'
            if (names.length > 1) {
              extractedData['Autres prénoms'] =
                  toTitleCase(names.sublist(1).join(' '));
            }
          }
          // print('Autres prénoms: ${extractedData['Autres prénoms']}');
          fieldsFound["Prénom"] = true;
        }
      }
    }
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.contains('sexe') && !fieldsFound["Sexe"]!) {
        String nextLine = "";
        try {
          nextLine = lines[i + 1].trim();
        } catch (e) {
          print('Error accessing next line: $e');
          continue;
        }

        if (nextLine.length == 1 &&
            (nextLine.toLowerCase() == 'f' || nextLine.toLowerCase() == 'm')) {
          if (nextLine.toLowerCase() == 'f') {
            extractedData['Sexe'] = 'f/f';
          } else if (nextLine.toLowerCase() == 'm') {
            extractedData['Sexe'] = 'm/m';
          }
          print('Sexe: $nextLine');
          fieldsFound["Sexe"] = true;
        }
      } else if (line.contains('nationalite') && !fieldsFound["Nationalité"]!) {
        String nextLine = lines[i + 1].trim();
        if (nextLine.toLowerCase().contains('nationality') &&
            i + 2 < lines.length &&
            RegExp(r'^[a-zA-Z]{1,3}$').hasMatch(lines[i + 2].trim())) {
          extractedData['Nationalité'] = lines[i + 2].trim();
          // print('Nationalité: ${lines[i + 2].trim()}');
          fieldsFound["Nationalité"] = true;
        }
      } else if (line.contains('date de naissance') &&
          !fieldsFound["Date de naissance"]!) {
        String nextLine = lines[i + 1].trim();
        if (nextLine.toLowerCase().contains('date of birth') &&
            i + 2 < lines.length) {
          String dateLine = lines[i + 2].trim();
          if (RegExp(r'^\d{2} \d{2} \d{4}$').hasMatch(dateLine)) {
            DateTime date = DateFormat('dd MM yyyy').parse(dateLine);
            extractedData['Date de naissance'] =
                DateFormat('dd/MM/yyyy').format(date);
            // print(
            //     'Date de naissance: ${DateFormat('dd/MM/yyyy').format(date)}');
            fieldsFound["Date de naissance"] = true;
          }
        }
      } else if (line.contains('n° registre national') &&
          !fieldsFound["N° Registre national"]!) {
        String nextLine = lines[i + 1].trim();
        if (RegExp(r'^\d{2}\.\d{2}\.\d{2}-\d{3}\.\d{2}$').hasMatch(nextLine)) {
          extractedData['N° Registre national'] = nextLine;
          print('N° Registre national: $nextLine');
          fieldsFound["N° Registre national"] = true;
        }
      } else if (line.contains('n° carte') && !fieldsFound["N° Carte"]!) {
        String nextLine = lines[i + 1].trim();
        if (RegExp(r'^\d{3}-\d{7}-\d{2}$').hasMatch(nextLine)) {
          extractedData['N° Carte'] = nextLine;
          // print('N° Carte: $nextLine');
          fieldsFound["N° Carte"] = true;
        }
      } else if (line.contains('expire le') && !fieldsFound["Expire le"]!) {
        String nextLine = lines[i + 1].trim();
        if (RegExp(r'^\d{2} \d{2} \d{4}$').hasMatch(nextLine)) {
          DateTime date = DateFormat('dd MM yyyy').parse(nextLine);
          extractedData['Expire le'] = DateFormat('dd/MM/yyyy').format(date);
          // print('Expire le: ${DateFormat('dd/MM/yyyy').format(date)}');
          fieldsFound["Expire le"] = true;
        }
      }
    }

    _isCardValid = fieldsFound.values.every((found) => found);
  }

  String toTitleCase(String text) {
    return text.replaceAll(RegExp(' +'), ' ').split(' ').map((word) {
      if (word.isNotEmpty) {
        return word[0].toUpperCase() + word.substring(1).toLowerCase();
      }
      return '';
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Lecteur de carte d\'identité'),
      ),
      body: Stack(
        children: [
          CameraPreview(_controller!),
          ClipPath(
            clipper: CardClipper(),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.5),
            ),
          ),
          Center(
            child: Container(
              width: 300,
              height: 180,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: validationProgress),
                duration: Duration(seconds: 1),
                builder: (context, progress, child) {
                  return CustomPaint(
                    painter: BorderPainter(progress),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get validationProgress {
    int validFields = fieldsFound.values.where((v) => v).length;
    return validFields / fieldsFound.length;
  }

  Future<void> _waitForAnimation() async {
    await Future.delayed(Duration(seconds: 1));
  }
}

// Définition du clipper personnalisé
class CardClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height / 2),
            width: 300,
            height: 180,
          ),
          Radius.circular(15),
        ),
      )
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..fillType = PathFillType.evenOdd;
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    return false;
  }
}

class BorderPainter extends CustomPainter {
  final double progress;

  BorderPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(10),
      ));

    final pathMetrics = path.computeMetrics().first;
    final extractPath =
        pathMetrics.extractPath(0, pathMetrics.length * progress);

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
