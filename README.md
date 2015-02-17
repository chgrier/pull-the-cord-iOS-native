# pull-the-cord-iOS-native
An iOS app that uses geofencing to alert the user when their selected transit stop is approaching.

The app uses native iOS region monitoring using the CoreLocation framework to monitor when the user enters a selected region.  A json file of the San Diego Trolley Blue Line were used to test the app.  

Add your own json file to create your own geofences.  

Format for json: {"name":"Transit Stop", "line":"Line Name", "latitude":xx.xxxxxx, "longitude":xxx.xxxxxx, "radius":xxx}
