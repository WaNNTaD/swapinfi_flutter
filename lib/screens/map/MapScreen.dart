import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final List<LatLng> patientLocations = [
    LatLng(37.7749, -122.4194), // San Francisco
    LatLng(34.0522, -118.2437), // Los Angeles
    LatLng(36.1699, -115.1398), // Las Vegas
  ];

  LatLng nurseLocation = LatLng(37.78825, -122.4324); // Position de l'infirmière
  List<LatLng> routePoints = [];

  @override
  void initState() {
    super.initState();
    getRoute();
  }

  Future<void> getRoute() async {
    final waypoints = patientLocations.map((p) => '${p.longitude},${p.latitude}').join(';');
    final url = 'http://router.project-osrm.org/route/v1/driving/${nurseLocation.longitude},${nurseLocation.latitude};$waypoints?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final route = data['routes'][0]['geometry']['coordinates'];
        setState(() {
          routePoints = route.map<LatLng>((point) => LatLng(point[1], point[0])).toList();
        });
      } else {
        print('Failed to load route');
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map Screen'),
      ),
      body: FlutterMap(
        options: MapOptions(
          center: nurseLocation,
          zoom: 10.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: nurseLocation,
                width: 80,
                height: 80,
                child: Icon(
                  Icons.person_pin_circle,
                  color: Colors.blue,
                  size: 40.0,
                ),
              ),
              ...patientLocations.map(
                (location) => Marker(
                  point: location,
                  width: 80,
                  height: 80,
                  child: Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40.0,
                  ),
                ),
              ),
            ],
          ),
          if (routePoints.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: routePoints,
                  strokeWidth: 4.0,
                  color: Colors.purple,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
