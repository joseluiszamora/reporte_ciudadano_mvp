import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/location/geo_point.dart';
import '../../../core/location/location_gateway.dart';
import 'coordinate_dialog.dart';
import 'location_controls.dart';
import 'location_cubit.dart';
import 'map_canvas.dart';
import 'map_tiles.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    super.key,
    required this.location,
    this.initial,
    this.tiles = MapTiles.create,
  });
  final LocationGateway location;
  final GeoPoint? initial;
  final TileProviderFactory tiles;
  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late final cubit = LocationCubit(widget.location, initial: widget.initial);
  @override
  void dispose() {
    cubit.close();
    super.dispose();
  }

  Future<void> coordinates() async {
    final point = await showCoordinateDialog(context, cubit.state.point);
    if (point != null && mounted) cubit.selectManual(point);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Elegir ubicación')),
    body: SafeArea(
      child: BlocBuilder<LocationCubit, LocationState>(
        bloc: cubit,
        builder: (context, state) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Toca el mapa para colocar el pin y arrástralo para ajustarlo. También puedes introducir las coordenadas.',
              ),
            ),
            Expanded(
              flex: 3,
              child: MapCanvas(
                focus: state.point,
                focusRevision: state.focusRevision,
                selected: state.point,
                onSelect: cubit.selectManual,
                tiles: widget.tiles,
              ),
            ),
            Flexible(
              flex:
                  state.error != null || (state.point?.isFarFromElAlto ?? false)
                  ? 2
                  : 0,
              fit: FlexFit.tight,
              child: SingleChildScrollView(
                child: LocationControls(
                  cubit: cubit,
                  state: state,
                  onCoordinates: coordinates,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.point == null
                      ? null
                      : () => Navigator.pop(context, state.point),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Confirmar ubicación'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
