import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/fullscreen_map_view.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Location Map'), elevation: 0),
      body: Column(
        children: [
          // Expanded map section that takes most of the screen
          const Expanded(child: FullscreenMapView()),
        ],
      ),
    );
  }
}
