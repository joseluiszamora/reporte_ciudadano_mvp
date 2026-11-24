import 'package:flutter/material.dart';

IconData categoryIcon(String key) => switch (key) {
  'road' => Icons.construction_rounded,
  'traffic' => Icons.traffic_rounded,
  'walk' => Icons.directions_walk_rounded,
  'light' => Icons.lightbulb_rounded,
  'delete' => Icons.delete_rounded,
  'water' => Icons.water_drop_rounded,
  'sign' => Icons.alt_route_rounded,
  _ => Icons.report_problem_rounded,
};
