import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:chatbox/services/websocket_service.dart';
import 'dart:async';

class LocationService {
  final WebSocketService wsService;
  StreamSubscription<Position>? _positionStream;

  LocationService(this.wsService);

  Future<void> requestPermissionsAndStart(String orderId, String courierId) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Los servicios de ubicación están deshabilitados.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Los permisos de ubicación fueron denegados.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      debugPrint('Los permisos están denegados permanentemente.');
      return;
    }

    // Si tenemos permiso, iniciamos la transmisión
    _startBroadcasting(orderId, courierId);
  }

  void _startBroadcasting(String orderId, String courierId) {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3, // Actualiza cada 3 metros
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        if (wsService.isConnected) {
          wsService.sendPayload({
            "type": "GPS_UPDATE",
            "order_id": orderId,
            "courier_id": courierId,
            "lat": position.latitude,
            "lng": position.longitude,
            "heading": position.heading,
          });
          debugPrint("📡 Emitiendo GPS: ${position.latitude}, ${position.longitude}");
        }
      }
    );
  }

  void stopBroadcasting() {
    _positionStream?.cancel();
    _positionStream = null;
  }
}

