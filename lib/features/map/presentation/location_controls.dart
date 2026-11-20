import 'package:flutter/material.dart';

import '../../../core/location/location_gateway.dart';
import 'location_cubit.dart';

class LocationControls extends StatelessWidget {
  const LocationControls({
    super.key,
    required this.cubit,
    required this.state,
    this.onCoordinates,
  });
  final LocationCubit cubit;
  final LocationState state;
  final VoidCallback? onCoordinates;

  Future<void> settings(BuildContext context, bool app) async {
    var opened = false;
    try {
      opened = await cubit.gateway.openSettings(appSettings: app);
    } catch (_) {
      /* Recover below. */
    }
    if (context.mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudieron abrir los ajustes. Puedes cambiar la ubicación desde los ajustes de Android.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: state.busy ? null : cubit.locate,
              icon: const Icon(Icons.my_location),
              label: Text(state.busy ? 'Buscando ubicación…' : 'Mi ubicación'),
            ),
            if (onCoordinates != null)
              TextButton.icon(
                onPressed: onCoordinates,
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Coordenadas'),
              ),
          ],
        ),
        if (state.error != null)
          Text(
            state.error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (state.failure == LocationFailure.deniedForever)
          TextButton(
            onPressed: () => settings(context, true),
            child: const Text('Abrir ajustes de permisos'),
          ),
        if (state.failure == LocationFailure.disabled)
          TextButton(
            onPressed: () => settings(context, false),
            child: const Text('Abrir ajustes de ubicación'),
          ),
        if (state.point != null) Text('Punto elegido: ${state.point!.label}'),
        if (state.point?.isFarFromElAlto ?? false)
          const Text(
            'Este punto está a más de 30 km del centro aproximado de El Alto. Revisa que sea la ubicación correcta.',
          ),
      ],
    ),
  );
}
