import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class MapDirectionScreen extends StatefulWidget {
  const MapDirectionScreen({super.key});

  @override
  State<MapDirectionScreen> createState() => _MapDirectionScreenState();
}

class _MapDirectionScreenState extends State<MapDirectionScreen> {
  final MapController _mapController = MapController();
  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isMapReady = false;

  String _destinationName = '';
  List<LatLng> _routePoints = [];
  double _routeDistance = 0;
  double _routeDuration = 0;

  final LatLng _defaultCenter = const LatLng(-6.2088, 106.8456); 

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _getCurrentLocation();
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  bool _isValidLatLng(LatLng? point) {
    if (point == null) return false;
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  LatLng? _sanitizeLatLng(double lat, double lng) {
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat.isNaN || lng.isNaN) return null;
    if (lat < -90 || lat > 90) return null;
    if (lng < -180 || lng > 180) return null;
    return LatLng(lat, lng);
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'OK',
          onPressed: () {
            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            }
          },
        ),
      ),
    );
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Layanan lokasi tidak aktif. Silakan aktifkan.');
      await Geolocator.openLocationSettings();
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Izin lokasi ditolak.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Izin lokasi ditolak permanen. Silakan aktifkan di pengaturan.');
      await Geolocator.openAppSettings();
      return false;
    }

    return true;
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final hasPermission = await _handleLocationPermission();
      if (!hasPermission) {
        if (!mounted) return;
        setState(() {
          _hasError = true;
          _errorMessage = 'Tidak dapat mengakses lokasi';
          _isLoading = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final currentPos = _sanitizeLatLng(position.latitude, position.longitude);
      if (currentPos == null) {
        throw Exception('Koordinat lokasi tidak valid');
      }

      if (!mounted) return;
      setState(() {
        _currentPosition = currentPos;
        _hasError = false;
        _isLoading = false;
      });

      if (_isValidLatLng(_destinationPosition)) {
        await _getRoute();
      }

      if (_isMapReady && _isValidLatLng(_currentPosition) && mounted) {
        _mapController.move(_currentPosition!, 15);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = 'Gagal mendapatkan lokasi: ${e.toString()}';
        _isLoading = false;
      });
      _showSnackBar(_errorMessage);
    }
  }

  Future<void> _getRoute() async {
    if (_currentPosition == null || _destinationPosition == null) return;
    if (!_isValidLatLng(_currentPosition) || !_isValidLatLng(_destinationPosition)) return;

    try {
      final start = '${_currentPosition!.longitude},${_currentPosition!.latitude}';
      final end = '${_destinationPosition!.longitude},${_destinationPosition!.latitude}';

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$start;$end'
        '?overview=full'
        '&geometries=geojson'
        '&steps=false'
        '&alternatives=false'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterMapApp/1.0'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Waktu permintaan habis'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final geometry = route['geometry'];

          if (geometry != null && geometry['coordinates'] != null) {
            final coordinates = geometry['coordinates'] as List;
            final points = coordinates.map((coord) {
              return LatLng(coord[1], coord[0]);
            }).toList();

            final distance = route['distance']?.toDouble() ?? 0.0;
            final duration = route['duration']?.toDouble() ?? 0.0;

            setState(() {
              _routePoints = points;
              _routeDistance = distance;
              _routeDuration = duration;
            });
          }
        } else {
          throw Exception('Rute tidak ditemukan');
        }
      } else {
        throw Exception('Gagal mendapatkan rute (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _routePoints = [_currentPosition!, _destinationPosition!];
        _routeDistance = _calculateDistance(_currentPosition!, _destinationPosition!);
        _routeDuration = _routeDistance / 11.11; 
      });
      _showSnackBar('Menggunakan rute garis lurus (OSRM tidak tersedia)');
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    if (!_isValidLatLng(point1) || !_isValidLatLng(point2)) return 0;
    
    const double R = 6371000; 
    final double lat1 = point1.latitude * pi / 180;
    final double lat2 = point2.latitude * pi / 180;
    final double dLat = (point2.latitude - point1.latitude) * pi / 180;
    final double dLng = (point2.longitude - point1.longitude) * pi / 180;

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) *
        sin(dLng / 2) * sin(dLng / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final distance = R * c;
    return distance.isFinite ? distance : 0;
  }

  void _zoomToRoute() {
    if (_routePoints.isEmpty || !_isMapReady) return;

    try {
      double sumLat = 0;
      double sumLng = 0;
      for (var point in _routePoints) {
        sumLat += point.latitude;
        sumLng += point.longitude;
      }

      final centerLat = sumLat / _routePoints.length;
      final centerLng = sumLng / _routePoints.length;
      final center = LatLng(centerLat, centerLng);

      double maxDistance = 0;
      for (var point in _routePoints) {
        final distance = _calculateDistance(center, point);
        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }

      double zoomLevel;
      if (maxDistance < 100) { zoomLevel = 18; }
      else if (maxDistance < 500) { zoomLevel = 16; }
      else if (maxDistance < 2000) { zoomLevel = 14; }
      else if (maxDistance < 5000) { zoomLevel = 13; }
      else if (maxDistance < 10000) { zoomLevel = 12; }
      else if (maxDistance < 20000) { zoomLevel = 11; }
      else if (maxDistance < 50000) { zoomLevel = 10; }
      else { zoomLevel = 8; }

      _mapController.move(center, zoomLevel);
    } catch (e) {
      if (_isValidLatLng(_destinationPosition)) {
        _mapController.move(_destinationPosition!, 14);
      }
    }
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) {
      _showSnackBar('Masukkan nama tempat');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}'
        '&format=json'
        '&limit=5'
        '&countrycodes=id'
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'FlutterMapApp/1.0'},
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Waktu permintaan habis'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.isEmpty) {
          _showSnackBar('Tempat tidak ditemukan');
          return;
        }

        if (data.length == 1) {
          final lat = double.parse(data[0]['lat']);
          final lng = double.parse(data[0]['lon']);
          final name = data[0]['display_name'];

          final newDest = _sanitizeLatLng(lat, lng);
          if (newDest == null) {
            _showSnackBar('Koordinat tidak valid');
            return;
          }

          setState(() {
            _destinationPosition = newDest;
            _destinationName = name;
          });

          await _getRoute();

          if (_isMapReady && mounted) {
            _zoomToRoute();
          }
          _showSnackBar('Tujuan: $name');
        } else {
          _showSearchResultDialog(data);
        }
      } else {
        throw Exception('Gagal mencari tempat (HTTP ${response.statusCode})');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
      _showSnackBar('Error: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSearchResultDialog(List<dynamic> results) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pilih Tujuan'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final item = results[index];
                final name = item['display_name'];
                final lat = double.parse(item['lat']);
                final lng = double.parse(item['lon']);

                return ListTile(
                  title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 12)),
                  onTap: () async {
                    final newDest = _sanitizeLatLng(lat, lng);
                    if (newDest != null) {
                      if (!mounted) return;
                      setState(() {
                        _destinationPosition = newDest;
                        _destinationName = name;
                      });
                      await _getRoute();
                      if (_isMapReady && mounted) {
                        _zoomToRoute();
                      }
                      _showSnackBar('Tujuan: $name');
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    } else {
      return '${meters.toStringAsFixed(0)} m';
    }
  }

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '0 menit';
    if (seconds >= 3600) {
      final int hours = (seconds / 3600).floor();
      final int minutes = ((seconds % 3600) / 60).round();
      return '$hours jam $minutes menit';
    } else if (seconds >= 60) {
      return '${(seconds / 60).round()} menit';
    } else {
      return '< 1 menit';
    }
  }

  Widget _buildMarker(bool isDestination) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDestination ? Colors.red : Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isDestination ? Icons.flag : Icons.my_location,
        color: Colors.white,
        size: 16,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigasi OpenStreetMap'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
            tooltip: 'Lokasi Saya',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Column(
                  children: [
                    if (_destinationName.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Column(
                          children: [
                            Text('Tujuan: $_destinationName', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(children: [const Icon(Icons.route, color: Colors.green), Text(_formatDistance(_routeDistance))]),
                                Column(children: [const Icon(Icons.timer, color: Colors.green), Text(_formatDuration(_routeDuration))]),
                              ],
                            )
                          ],
                        ),
                      ),
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _currentPosition ?? _defaultCenter,
                          initialZoom: 15,
                          onTap: (tapPosition, point) async {
                            if (_isMapReady && _isValidLatLng(point) && mounted) {
                              setState(() {
                                _destinationPosition = point;
                                _destinationName = 'Lat: ${point.latitude.toStringAsFixed(6)}, Lng: ${point.longitude.toStringAsFixed(6)}';
                              });
                              await _getRoute();
                              _showSnackBar('Tujuan diubah');
                            }
                          },
                          onMapReady: () {
                            if (!mounted) return;
                            setState(() { _isMapReady = true; });
                            if (_isValidLatLng(_currentPosition)) {
                              _mapController.move(_currentPosition!, 15);
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          if (_routePoints.isNotEmpty && _routePoints.length > 1)
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: _routePoints,
                                  color: Colors.blue,
                                  strokeWidth: 5,
                                  borderColor: Colors.blue,
                                  borderStrokeWidth: 7,
                                ),
                              ],
                            ),
                          MarkerLayer(
                            markers: [
                              if (_isValidLatLng(_currentPosition))
                                Marker(
                                  point: _currentPosition!,
                                  width: 40,
                                  height: 40,
                                  child: _buildMarker(false),
                                ),
                              if (_isValidLatLng(_destinationPosition))
                                Marker(
                                  point: _destinationPosition!,
                                  width: 40,
                                  height: 40,
                                  child: _buildMarker(true),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue,
                    onPressed: () {
                       _searchPlace("Monas, Jakarta"); 
                    },
                    child: const Icon(Icons.search),
                  ),
                ),
                 if (_routePoints.isNotEmpty)
                 Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    onPressed: () {
                        setState(() {
                          _destinationPosition = null;
                          _destinationName = '';
                          _routePoints = [];
                        });
                    },
                    child: const Icon(Icons.clear),
                  ),
                )
              ],
            ),
    );
  }
}