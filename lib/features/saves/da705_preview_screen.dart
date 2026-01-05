import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class Da705PreviewScreen extends StatelessWidget {
  const Da705PreviewScreen({super.key, required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DA Form 705'),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              final size = MediaQuery.sizeOf(context);
              Rect origin = Rect.fromCenter(
                center: size.center(Offset.zero),
                width: 1,
                height: 1,
              );
              final box = context.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final topLeft = box.localToGlobal(Offset.zero);
                origin = topLeft & box.size;
              }
              Share.shareXFiles(
                [XFile(file.path, mimeType: 'application/pdf')],
                subject: 'DA Form 705',
                text: 'DA Form 705 export from AFT',
                sharePositionOrigin: origin,
              );
            },
          ),
        ],
      ),
      body: SfPdfViewer.file(file),
    );
  }
}
