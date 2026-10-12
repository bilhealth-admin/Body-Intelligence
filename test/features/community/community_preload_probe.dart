import 'package:flutter/material.dart';

class CommunityPreloadProbe extends StatefulWidget {
  const CommunityPreloadProbe({super.key, required this.onInit});
  final VoidCallback onInit;
  @override
  State<CommunityPreloadProbe> createState() => _ProbeState();
}

class _ProbeState extends State<CommunityPreloadProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('TEST prepared feed'));
}
