import 'package:flutter/material.dart';
import 'safety_vertex.dart';

class TriangleOfSafetySection extends StatelessWidget {
  const TriangleOfSafetySection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Triangle of Safety',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Three vertices of safety
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SafetyVertex(
                title: 'You',
                icon: Icons.person,
                color: Colors.purple,
              ),
              SafetyVertex(
                title: 'App',
                icon: Icons.phone_android,
                color: Colors.blue,
              ),
              SafetyVertex(
                title: 'Bracelet',
                icon: Icons.watch,
                color: Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Complete protection through our three-point safety system',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
