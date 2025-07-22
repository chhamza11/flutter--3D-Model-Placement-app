import 'package:ar_flutter_plugin_2/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_2/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_2/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_2/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_2/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_2/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_2/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_2/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_2/models/ar_node.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vmath;
import 'package:collection/collection.dart';

class ARScreen extends StatefulWidget {
  const ARScreen({super.key});
  @override
  ARScreenState createState() => ARScreenState();
}

class ARScreenState extends State<ARScreen> {
  late ARSessionManager arSessionManager;
  late ARObjectManager arObjectManager;
  late ARAnchorManager arAnchorManager;

  List<ARNode> nodes = [];
  List<ARAnchor> anchors = [];
  bool isDarkTheme = false;
  bool isPlacing = false;

  @override
  void dispose() {
    super.dispose();
    arSessionManager.dispose();
  }

  void _toggleTheme() {
    setState(() {
      isDarkTheme = !isDarkTheme;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = isDarkTheme ? ThemeData.dark() : ThemeData.light();
    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AR Reality Model'),
          actions: [
            IconButton(
              icon: Icon(isDarkTheme ? Icons.light_mode : Icons.dark_mode),
              tooltip: isDarkTheme ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              onPressed: _toggleTheme,
            ),
          ],
        ),
        body: Stack(children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontal,
          ),
          if (isPlacing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Placing model...', style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),
        ]),
        floatingActionButton: _buildFAB(context),
      ),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'reset',
          tooltip: 'Remove All',
          child: const Icon(Icons.delete_outline),
          onPressed: onRemoveEverything,
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'gallery',
          tooltip: 'Model Gallery',
          child: const Icon(Icons.view_in_ar),
          onPressed: () {
            // TODO: Show model gallery bottom sheet
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Model gallery coming soon!')),
            );
          },
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          heroTag: 'screenshot',
          tooltip: 'Screenshot',
          child: const Icon(Icons.camera_alt),
          onPressed: () {
            // TODO: Implement screenshot feature
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Screenshot feature coming soon!')),
            );
          },
        ),
      ],
    );
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager.onInitialize(
          showFeaturePoints: false,
          showPlanes: true,
          handleTaps: true,
          handlePans: true,
          handleRotation: true,
        );
    this.arObjectManager.onInitialize();

    this.arSessionManager.onPlaneOrPointTap = onPlaneOrPointTapped;
  }

  Future<void> onRemoveEverything() async {
    for (var anchor in anchors) {
      arAnchorManager.removeAnchor(anchor);
    }
    anchors = [];
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All models removed.')),
    );
  }

  Future<void> onPlaneOrPointTapped(
      List<ARHitTestResult> hitTestResults) async {
    var singleHitTestResult = hitTestResults.firstWhereOrNull(
        (hitTestResult) => hitTestResult.type == ARHitTestResultType.plane);
    if (singleHitTestResult != null) {
      setState(() => isPlacing = true);
      var newAnchor =
          ARPlaneAnchor(transformation: singleHitTestResult.worldTransform);
      bool? didAddAnchor = await arAnchorManager.addAnchor(newAnchor);
      if (didAddAnchor ?? false) {
        anchors.add(newAnchor);
        var newNode = ARNode(
            type: NodeType.webGLB,
            uri:
                "https://github.com/KhronosGroup/glTF-Sample-Models/raw/main/2.0/Duck/glTF-Binary/Duck.glb",
            scale: vmath.Vector3(0.2, 0.2, 0.2));
        bool? didAddNodeToAnchor =
            await arObjectManager.addNode(newNode, planeAnchor: newAnchor);
        if (didAddNodeToAnchor ?? false) {
          nodes.add(newNode);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Model placed!')),
          );
        } else {
          arSessionManager.onError?.call("Adding Node to Anchor failed");
        }
      } else {
        arSessionManager.onError?.call("Adding Anchor failed");
      }
      setState(() => isPlacing = false);
    }
  }
} 