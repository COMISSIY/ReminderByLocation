import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MaterialApp(debugShowCheckedModeBanner:false, home:ReminderByLocation()));
}
final database = openDatabase(
  'location_marks.db',
  onCreate: (db, version) {
    return db.execute(
      'CREATE TABLE location_marks(id INTEGER PRIMARY KEY, name TEXT, latitude REAL, longitude REAL)',
    );
  },
  version: 1,
);

Future<void> insertLocationMark(LocationMark locationMark) async {
  final db = await database;
  await db.insert(
    'location_marks',
    locationMark.toMap(),
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}
List<Geofence> locationMarkToGeofenceList(List<LocationMark> locationMarks){
  List<Geofence> result = [];
  for (int i = 0; i < locationMarks.length; i++){
    result.add(Geofence(
    id: locationMarks[i].name,
    latitude: locationMarks[i].latitude,
    longitude: locationMarks[i].longitude,
    radius: [
      GeofenceRadius(id: 'radius_100m', length: 500),
    ],
  ));
  };
  print(result);
  return result;
}
Future<List<LocationMark>> locationMarks() async {
  final db = await database;
  final List<Map<String, dynamic>> maps = await db.query('location_marks');
  return List.generate(maps.length, (i) {
    return LocationMark(
      id: maps[i]['id'] as int,
      name: maps[i]['name'] as String,
      latitude: maps[i]["latitude"] as double,
      longitude: maps[i]["longitude"] as double
    );
  });
}

Future<void> deleteLocationMark(String name) async {
  final db = await database;
  await db.delete(
    'location_marks',
    where: 'name = ?',
    whereArgs: [name],
  );
}

List<Geofence> _geofenceList = [];
late YandexMapController controller;
final _geofenceService = GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 10000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: true,
    allowMockLocations: false,
    printDevLog: false,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC);

showAlertDialog(BuildContext context, String markName) {
  AlertDialog alert = AlertDialog(
    title: const Text("Notification"),
    content: Text("You reach the location: $markName"),
  );
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return alert;
    },
  );
}

class ReminderByLocation extends StatefulWidget {
  const ReminderByLocation({Key? key}) : super(key: key);
  @override
  State<ReminderByLocation> createState() => _ReminderByLocationState();
}

class _ReminderByLocationState extends State<ReminderByLocation> {
  int currentPageIndex = 1;
  String markName = "";
  // String markDescription = "";
  Point? markLocation;
  bool selectionMode = false;
  final _markFormKey = GlobalKey<FormState>();
  final _activityStreamController = StreamController<Activity>();
  final _geofenceStreamController = StreamController<Geofence>();
  Location? userPosition;

  List<MapObject> _getMarks(){
    List<MapObject> marksList = [];
    if (userPosition != null) {
      marksList.add(PlacemarkMapObject(
        text: PlacemarkText(text: "user", style: PlacemarkTextStyle(color: Colors.green, size: 24)),
        mapId: const MapObjectId("UserPosition"),
        point: Point(latitude: userPosition!.latitude, longitude: userPosition!.longitude),
      ));
    }
    for (int i = 0; i < _geofenceList.length; i++){
      marksList.add(CircleMapObject(
        mapId: MapObjectId(_geofenceList[i].id),
        circle: Circle(
          center: Point(latitude: _geofenceList[i].latitude, longitude: _geofenceList[i].longitude),
          radius: 100,
        ),
        fillColor: const Color.fromRGBO(255, 0, 0, 0.5),
        strokeWidth: 2,
        strokeColor: Colors.black,
      )
      );
    }
    if (selectionMode == true && markLocation != null){
      marksList.add(CircleMapObject(
        mapId: MapObjectId("selectionMark"),
        circle: Circle(
          center: Point(latitude: markLocation!.latitude, longitude: markLocation!.longitude),
          radius: 100,
        ),
        fillColor: const Color.fromRGBO(0, 0, 255, 0.5),
        strokeWidth: 2,
        strokeColor: Colors.black,
      ));
    }

    return marksList;
  }
  Future<void> _onGeofenceStatusChanged(
      Geofence geofence,
      GeofenceRadius geofenceRadius,
      GeofenceStatus geofenceStatus,
      Location location) async {
    print('geofence: ${geofence.toJson()}');
    print('geofenceRadius: ${geofenceRadius.toJson()}');
    print('geofenceStatus: ${geofenceStatus.toString()}');
    if (geofenceStatus.toString() == "GeofenceStatus.ENTER"){
      showAlertDialog(context, geofence.id);
    }
    _geofenceStreamController.sink.add(geofence);
  }

  void _onActivityChanged(Activity prevActivity, Activity currActivity) {
    print('prevActivity: ${prevActivity.toJson()}');
    print('currActivity: ${currActivity.toJson()}');
    _activityStreamController.sink.add(currActivity);
  }

  void _onLocationChanged(Location location) {
    setState(() {
      userPosition = location;
    });
  }

  void _onLocationServicesStatusChanged(bool status) {
    print('isLocationServicesEnabled: $status');
  }

  void _onError(error) {
    final errorCode = getErrorCodesFromError(error);
    if (errorCode == null) {
      print('Undefined error: $error');
      return;
    }
    print('ErrorCode: $errorCode');
  }

  @override
  void initState() {
    locationMarks().then((value) => {
      _geofenceService.addGeofenceList(locationMarkToGeofenceList(value))
    });
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
      _geofenceService.addLocationChangeListener(_onLocationChanged);
      _geofenceService.addLocationServicesStatusChangeListener(_onLocationServicesStatusChanged);
      _geofenceService.addActivityChangeListener(_onActivityChanged);
      _geofenceService.addStreamErrorListener(_onError);
      _geofenceService.start(_geofenceList).catchError(_onError);
    });
  }
  @override
  Widget build(BuildContext context) {
    GeofenceService.instance.start();
    locationMarks().then((value) => {
      _geofenceList = locationMarkToGeofenceList(value)});

    return WillStartForegroundTask(
      onWillStart: () async {
        return _geofenceService.isRunningService;
      },
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'geofence_service_notification_channel',
        channelName: 'Geofence Service Notification',
        channelDescription: 'This notification appears when the geofence service is running in the background.',
        channelImportance: NotificationChannelImportance.HIGH,
        priority: NotificationPriority.LOW,
        isSticky: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(),
      notificationTitle: 'Location tracking is active',
      notificationText: "Do not close the app",
      child: Scaffold(
          bottomNavigationBar: NavigationBar(
            onDestinationSelected: (int index) {
              setState(() {
                currentPageIndex = index;
                selectionMode = false;
              });
            },
            selectedIndex: currentPageIndex,
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.list_alt),
                label: 'Marks',
              ),
              NavigationDestination(
                icon: Icon(Icons.map),
                label: 'Map',
              ),
              NavigationDestination(
                icon: Icon(Icons.edit),
                label: 'Edit',
              ),
            ],
          ),
          body: IndexedStack(
            index: currentPageIndex,
            children: <Widget>[
              ListView.builder(
                  itemCount: _geofenceList.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Row(
                      children: [Expanded(
                        child: ElevatedButton(
                            child: Text(_geofenceList[index].id,
                                style: const TextStyle(fontSize: 22)),
                            onPressed: () async {
                              setState(() => currentPageIndex = 1);
                              await controller.moveCamera(
                                CameraUpdate.newCameraPosition(
                                    CameraPosition(
                                        target: Point(latitude: _geofenceList[index].latitude, longitude: _geofenceList[index].longitude),
                                        zoom: 15)
                                ),
                                animation: const MapAnimation(type: MapAnimationType.linear, duration: 1),
                              );
                            }),
                      ),
                      IconButton(
                        onPressed: (){
                          setState(() {
                            _geofenceService.removeGeofence(_geofenceList[index]);
                            deleteLocationMark(_geofenceList[index].id);
                            locationMarks().then((value) => {
                              _geofenceList = locationMarkToGeofenceList(value)
                            });

                          });
                      }, icon: Icon(Icons.cancel),)]
                    );
                  }
              ),
              YandexMap(
                mapObjects: _getMarks(),
                onMapTap: (point) {
                  setState(() {
                    markLocation = point;
                  });
                },
                  onMapCreated: (YandexMapController yandexMapController) async {
                controller = yandexMapController;

                final cameraPosition = await controller.getCameraPosition();
                final minZoom = await controller.getMinZoom();
                final maxZoom = await controller.getMaxZoom();

                print('Camera position: $cameraPosition');
                print('Min zoom: $minZoom, Max zoom: $maxZoom');
              }),
            Form(
                key: _markFormKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextFormField(
                      onSaved: (value){
                        markName = value!;
                      },
                      decoration: const InputDecoration(
                        hintText: "Mark's name",
                      ),
                      validator: (value) {
                        for (int i = 0; i < _geofenceList.length; i++){
                          if (_geofenceList[i].id == value){
                            return "Please select unique name";
                          }
                        }
                        return null;
                      },
                    ),
                    // TextFormField(
                    //   validator: (value){
                    //     if (value == null || value.isEmpty){
                    //       return "Please, give mark a description";
                    //     }
                    //     return null;
                    //   },
                    //   decoration: const InputDecoration(
                    //     hintText: "Description"
                    //   ),
                    // ),
                    ElevatedButton(
                        onPressed: (){
                          setState(() {
                            selectionMode = true;
                            currentPageIndex = 1;
                          });
                    },
                        child: const Text("Select position")
                    ),
                    ElevatedButton(
                        onPressed: (markLocation == null && selectionMode == false) ? null : (){
                          if (_markFormKey.currentState!.validate()){
                            _markFormKey.currentState!.save();
                            final newGeofence = Geofence(
                              id: markName,
                              latitude: markLocation!.latitude,
                              longitude: markLocation!.longitude,
                              radius: [
                                GeofenceRadius(id: 'radius_100m', length: 500),
                              ],
                            );
                            insertLocationMark(LocationMark(
                                id: _geofenceList.length,
                                name: markName,
                                latitude: markLocation!.latitude,
                                longitude: markLocation!.longitude
                              )
                            );
                            locationMarks().then((value) => {
                              _geofenceList = locationMarkToGeofenceList(value)
                            });
                            _geofenceService.addGeofence(newGeofence);
                            markLocation = null;
                            selectionMode = false;
                          }
                        },
                        child: const Text("Submit")
                    )
                  ],
                ),
              ),
            ],
          )
      ),
    );
  }
}