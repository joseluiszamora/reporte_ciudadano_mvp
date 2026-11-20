import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/media/local_photo_reader.dart';

class ReportPhoto extends StatefulWidget {
  const ReportPhoto({
    super.key,
    required this.path,
    required this.reader,
    this.expandable = true,
  });
  final String? path;
  final LocalPhotoReader reader;
  final bool expandable;
  @override
  State<ReportPhoto> createState() => _ReportPhotoState();
}

class _ReportPhotoState extends State<ReportPhoto> {
  late Future<File?> file;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant ReportPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.reader != widget.reader) {
      load();
    }
  }

  void load() {
    file = widget.path == null
        ? Future.value()
        : widget.reader.open(widget.path!);
  }

  Widget missing() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.broken_image_outlined),
        const Text('Fotografía no disponible', textAlign: TextAlign.center),
        if (widget.expandable) ...[
          const Text(
            'Vuelve a adjuntarla al editar el reporte.',
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () => setState(load),
            child: const Text('Reintentar foto'),
          ),
        ],
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: FutureBuilder<File?>(
      future: file,
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (image == null) return missing();
        return Semantics(
          label: 'Fotografía del reporte',
          hint: widget.expandable ? 'Abre la fotografía ampliada' : null,
          button: widget.expandable,
          child: GestureDetector(
            onTap: !widget.expandable
                ? null
                : () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute<void>(
                      builder: (_) => Scaffold(
                        appBar: AppBar(title: const Text('Fotografía')),
                        body: Center(
                          child: InteractiveViewer(
                            maxScale: 5,
                            child: Image.file(
                              image,
                              errorBuilder: (_, _, _) => missing(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            child: Image.file(
              image,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => missing(),
            ),
          ),
        );
      },
    ),
  );
}
