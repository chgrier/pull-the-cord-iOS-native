# Pull the Cord!
###Transit Alerts using iOS CoreLocation

######Description:
An iOS app that uses geofencing to alert the user when their selected transit stop is approaching.

The app uses native iOS region monitoring using the CoreLocation framework to monitor when the user enters a selected region.  A JSON file of the San Diego Trolley Blue Line was used to test the app

To add your own JSON file to create your own geofences, use the following JSON format:
```sh
 {"name":"Transit Stop", "line":"Line Name", "latitude":xx.xxxxxx, "longitude":xxx.xxxxxx, "radius":xxx}
```

######Features: 
- CoreLocation to trigger alerts when entering a user-specified region.
- MapKit for mapping routes and stations.
    - MKOverlayRenderer for mapping transit lines.
    - MKAnnotationView for map callouts and annotations.
- AVFoundation to create audible alerts.
    - AVSpeechSynthesizer to produce synthesized speech to alert the user of their upcoming station.
- UILocalNotification provides nofications when app is running in the background.
- NSJSONSerialization to convert JSON-formatted station to Foundation objects for mapping.

######Screen Shots:
<img src="http://charlesgrier.com/screen_shots/Pull-the-Cord-iPhone6_alert-225x400.png" height="400" width="200">
<img src="http://www.charlesgrier.com/screen_shots/Pull-the-Cord-iPhone6_400x600.png" height="400" width="200">


 
