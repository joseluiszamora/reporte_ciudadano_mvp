import 'package:flutter/material.dart';

import '../../../core/location/geo_point.dart';

Future<GeoPoint?> showCoordinateDialog(
  BuildContext context,
  GeoPoint? initial,
) => showDialog<GeoPoint>(
  context: context,
  builder: (_) => _CoordinateDialog(initial),
);

class _CoordinateDialog extends StatefulWidget {
  const _CoordinateDialog(this.initial);
  final GeoPoint? initial;
  @override
  State<_CoordinateDialog> createState() => _CoordinateDialogState();
}

class _CoordinateDialogState extends State<_CoordinateDialog> {
  final form = GlobalKey<FormState>();
  late final latitude = TextEditingController(
    text: widget.initial?.latitude.toString(),
  );
  late final longitude = TextEditingController(
    text: widget.initial?.longitude.toString(),
  );
  double? number(String? text) =>
      double.tryParse((text ?? '').trim().replaceAll(',', '.'));
  String? validate(String? text, double limit) {
    final value = number(text);
    return value == null || !value.isFinite || value < -limit || value > limit
        ? 'Introduce un valor entre -$limit y $limit.'
        : null;
  }

  @override
  void dispose() {
    latitude.dispose();
    longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Introducir coordenadas'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Puedes usar esta opción sin GPS y sin conexión al mapa.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: latitude,
              decoration: const InputDecoration(labelText: 'Latitud'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) => validate(value, 90),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: longitude,
              decoration: const InputDecoration(labelText: 'Longitud'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              validator: (value) => validate(value, 180),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              GeoPoint(number(latitude.text)!, number(longitude.text)!),
            );
          }
        },
        child: const Text('Usar coordenadas'),
      ),
    ],
  );
}
