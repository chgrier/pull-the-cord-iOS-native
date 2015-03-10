//
//  CHGMainViewController.m
//  Pull the Cord Native
//
//  Created by Charles Grier on 1/27/15.
//  Copyright (c) 2015 Grier Mobile Development. All rights reserved.
//

#import "CHGMainViewController.h"
@import CoreLocation;
@import MapKit;
#import "CHGStation.h"
@import AVFoundation;

typedef void (^CHGLocationCallback)(CLLocationCoordinate2D);

@interface CHGMainViewController () <CLLocationManagerDelegate, MKMapViewDelegate>
{
    BOOL _didStartMonitoringRegion;
    BOOL _inRegion;
    CHGLocationCallback _foundLocationCallback;
}

@property (strong, nonatomic) NSMutableArray *stations;
@property (strong, nonatomic) MKPolyline *mapPolyline;
@property (strong, nonatomic) MKCircle *stationCircle;
@property (strong, nonatomic) AVSpeechSynthesizer *speechSynthesizer;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
//@property (weak, nonatomic) IBOutlet UILabel *stationMessageLabel;
@property (weak, nonatomic) IBOutlet UIButton *stationMessageButton;

@property (weak, nonatomic) IBOutlet UILabel *arrivalMessageLabel;

@end

@implementation CHGMainViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    // New for iOS 8 - Register the notifications
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings *mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:mySettings];

    [self.stationMessageButton setEnabled:NO];
    
    self.navigationItem.leftBarButtonItem = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Clear Alerts" style:UIBarButtonItemStyleBordered target:self action:@selector(stopRegionMonitoring:clearRegions:)];
    
    self.locationManager = [[CLLocationManager alloc]init];
    self.locationManager.delegate = self;
    
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
    }
    [self.locationManager startUpdatingLocation];
    
    self.mapView.delegate = self; // ***make sure to set delegate***
    self.mapView.showsUserLocation = YES;
    
    // add station and line info when view loads
    [self loadStationData];
    
    // center map on San Diego
    CLLocationCoordinate2D center = CLLocationCoordinate2DMake(32.6673224,-117.0856415);
    MKCoordinateSpan span = MKCoordinateSpanMake(0.2, 0.2); // one degree of latitude is 69 miles; longitude varies
    MKCoordinateRegion regionToDisplay = MKCoordinateRegionMake(center, span);
    [self.mapView setRegion:regionToDisplay animated:NO];
    
   // MKCircle *circle = [MKCircle circleWithCenterCoordinate:center radius:1000];
   // [self.mapView addOverlay:circle];
    
    [self.mapView addOverlay:self.mapPolyline];
    [self.mapView addAnnotations:self.stations];
    
}

#pragma mark CLLocation Manager Delegate Methods

-(void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
    // NSLog(@"%@", [locations lastObject]);
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error
{
    NSLog(@"didFailWithError %@", error);
}


// if location authorization not allowed, provide a way to get to notify user and change in Settings
- (void)requestAlwaysAuthorization
{
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    
    // If the status is denied or only granted for when in use, display an alert
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusDenied) {
        NSString *title = (status == kCLAuthorizationStatusDenied) ? @"Location services \nare turned off" : @"Background location is not enabled";
        NSString *message = @"To receive alerts, you must change the Location Services Settings to 'Always'";
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            NSLog(@"Alert Action: Cancel pressed");
        }];
        
        UIAlertAction *settings = [UIAlertAction actionWithTitle:@"Location Settings" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSURL *settingsURL = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
            [[UIApplication sharedApplication] openURL:settingsURL];

        }];
        
        [alertController addAction:cancel];
        [alertController addAction:settings];
        
        [self presentViewController:alertController animated:YES completion:nil];

    }
    // If the user has not enabled any location services, request background authorization.
    else if (status == kCLAuthorizationStatusNotDetermined) {
        [self.locationManager requestAlwaysAuthorization];
    }
}


// load data from json files -- based on Ray Wenderlich What's New with MapKit from iOS 6 by Tutorials v3.2 pp. 1001 - 1003 by Matt Galloway
// TODO - load from web rather than bundle

- (void)loadStationData {
    // Read data from JSON file into an array using NSJSONSerialization class to convert to Foundation objects
    NSData *data = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"sdmts_blueLine" ofType:@"json"]];
    NSArray *stationData = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]; // 0 = kNilOptions
    NSUInteger stationCount = stationData.count; // determines the number of stations for the array
    
    // create a C-style array based on the station count size
    NSUInteger i = 0;
    CLLocationCoordinate2D *polylineCoords = malloc(sizeof(CLLocationCoordinate2D) *stationCount); // used malloc manually allocate memory for block of memory of size equal to the size of each element multiplied by the number of elements
    self.stations = [[NSMutableArray alloc]initWithCapacity:stationCount];
   
    // create dictionary to hold JSON data then loop through stationData array using for loop
    for (NSDictionary *stationDictionary in stationData) {
        // create coordinate pairs then add to polyLineCoords array
        CLLocationDegrees latitude = [[stationDictionary objectForKey:@"latitude"] doubleValue];
        CLLocationDegrees longitude = [[stationDictionary objectForKey:@"longitude"] doubleValue];
        CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(latitude, longitude);
        polylineCoords[i] = coordinate;
        
        // create new station object and add add above coordinates, name, line, and radius for geofence specified in JSON file
        CHGStation *station = [[CHGStation alloc]init];
        station.title = [stationDictionary objectForKey:@"name"];
        station.stationName = [stationDictionary objectForKey:@"name"];
        station.lineName = [stationDictionary objectForKey:@"line"];
        station.subtitle = [stationDictionary objectForKey:@"line"];
        station.coordinate = coordinate;
        station.radius = [stationDictionary objectForKey:@"radius"];
        [self.stations addObject:station];
        
        i++;
        }
        // create an array for polyline using coordinates from above
        self.mapPolyline = [MKPolyline polylineWithCoordinates:polylineCoords count:stationCount];
            
        // make sure to free memory, but after for loop - ARC cannot free after using malloc
        free(polylineCoords);
    
}


- (void)didReceiveMemoryWarning {

    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

# pragma mark - Map Overlay Delegate
-(MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    if ([overlay isKindOfClass:[MKPolyline class]]){
    MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc]initWithPolyline:overlay];
    renderer.lineWidth = 6.0f;
    renderer.strokeColor = [UIColor blueColor];
        return renderer;
    }
    
    if ([overlay isKindOfClass:[MKCircle class]]){
    MKCircleRenderer *circleRenderer = [[MKCircleRenderer alloc]initWithCircle:overlay];
        circleRenderer.lineWidth = 4.0f;
        circleRenderer.strokeColor = [UIColor colorWithRed:0.7 green:0 blue:0 alpha:0.5];
        circleRenderer.fillColor = [UIColor colorWithRed:1.0 green:0 blue:0 alpha:0.1];
        
    return circleRenderer;
    }
    return nil;
}

# pragma mark - Annotation Delegate
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[CHGStation class]]) {
        static NSString *const kPinIdentifier = @"CHGStation";
        MKAnnotationView *view = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:kPinIdentifier];
        
        if (!view) {
            
            view = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:kPinIdentifier];
            view.annotation = annotation;
            view.canShowCallout = YES;
            //view.calloutOffset = CGPointMake(-5, 5);
        
            //view.pinColor = MKPinAnnotationColorRed;
            view.draggable = NO;
            UIImageView *myCustomImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"trolleyIcon"]];
            view.image = [UIImage imageNamed:@"trolleyIcon"];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
            // Add a custom image to the left side of the callout.
            
            view.leftCalloutAccessoryView = myCustomImage;
            view.rightCalloutAccessoryView = button;
        } else {
            //view.rightCalloutAccessoryView = nil;
        }
        
        return view;
    
    }
    return nil;
}

#pragma mark -- Annotation Callout Tapped Delegate
// Handle to set monitoring for geofence when callout button is tapped
-(void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
    [self requestAlwaysAuthorization];
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusDenied) {
        return;
    } else {
    CHGStation *selectedStation = (CHGStation *)view.annotation;
    
        NSString *title = @"Set alert";
        NSString *message = [NSString stringWithFormat:@"Get notified when you are approaching the %@", selectedStation.title];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            NSLog(@"Alert Action: Cancel pressed");
        }];
        
        UIAlertAction *setAlert = [UIAlertAction actionWithTitle:@"Set Alert" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            //[self.locationManager startUpdatingLocation];
            [self selectStationAndZoom:selectedStation];
            [self monitorSelectedStation:selectedStation];
            
        }];
        
        [alertController addAction:cancel];
        [alertController addAction:setAlert];
        
        [self presentViewController:alertController animated:YES completion:nil];
        
        UIPopoverPresentationController *popover = alertController.popoverPresentationController;
        if (popover)
        {
            popover.sourceView = view;
            popover.sourceRect = view.bounds;
            popover.permittedArrowDirections = UIPopoverArrowDirectionAny;
        }
        
    }
}

-(void)selectStationAndZoom:(CHGStation *)selectedStation {
    
    [self showAlertforRegionMonitoring:selectedStation];
    if (self.stationCircle) {
        [self.mapView removeOverlay:self.stationCircle];
    }
    
    self.stationCircle = [MKCircle circleWithCenterCoordinate:selectedStation.coordinate radius:[selectedStation.radius floatValue]];
    self.stationCircle.title = @"%@", [NSString stringWithFormat:@"%@", selectedStation.title];
    
    [self.mapView addOverlay:self.stationCircle];
    
    
    MKCoordinateSpan span = MKCoordinateSpanMake(0.025, 0.025); // one degree of latitude is 69 miles; longitude varies
    MKCoordinateRegion regionToDisplay = MKCoordinateRegionMake(self.stationCircle.coordinate, span);
    [self.mapView setRegion:regionToDisplay animated:YES];
    
 
}

// zoom to station with alert
- (IBAction)zoomToSelectedStation:(id)sender {
    MKCoordinateSpan span = MKCoordinateSpanMake(0.025, 0.025); // one degree of latitude is 69 miles; longitude varies
    MKCoordinateRegion regionToDisplay = MKCoordinateRegionMake(self.stationCircle.coordinate, span);
    [self.mapView setRegion:regionToDisplay animated:YES];
}

#pragma mark - Region Monitoring (Geofencing) Methods

// start monitoring for region
-(void)monitorSelectedStation:(CHGStation *)station {

    for (CLRegion *region in [[self.locationManager monitoredRegions] allObjects]) {
        if (![region.identifier isEqualToString:station.title]) {
            [self.locationManager stopMonitoringForRegion:region];
        }
    }

    [self.locationManager startMonitoringForRegion:[[CLCircularRegion alloc]initWithCenter:station.coordinate radius:[station.radius floatValue] identifier:station.title]];
    
}

// alert view for region monitoring
-(void)showAlertforRegionMonitoring:(CHGStation *)station {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert set!"
                                                    message:[NSString stringWithFormat:@"You will be notified when approaching %@", station.title]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    
}

// delegates for region monitoring
-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    
    self.arrivalMessageLabel.text = @"Arriving at:";
    //self.stationMessageButton.titleLabel.text = [NSString stringWithFormat:@"%@", region.identifier];
    [self.stationMessageButton setTitle:[NSString stringWithFormat:@"%@", region.identifier] forState:UIControlStateNormal];
    
    [self didEnterRegionAlert:region];
    [self.locationManager stopMonitoringForRegion:region];
    [self.locationManager stopUpdatingLocation];
    
}

-(void)didEnterRegionAlert:(CLRegion *)region {
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = [NSString stringWithFormat:@"Arriving at %@", region.identifier];
    notification.soundName = @"School Bell Ringing.caf";
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    
    
    NSString *title = @"Arriving at your station";
    NSString *message = [NSString stringWithFormat:@"You are approaching %@", region.identifier];
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
        
        NSLog(@"Alert Action: OK pressed");
        //[self.locationManager stopMonitoringForRegion:region];
        NSLog(@"Regions being currently monitored: %@", [self.locationManager monitoredRegions]);
        
        
    }];
    
    NSLog(@"You just entered geofence %@",region.identifier);
    [alertController addAction:ok];
    
    [self presentViewController:alertController animated:YES completion:nil];
    
    self.speechSynthesizer = [[AVSpeechSynthesizer alloc]init];
    static AVSpeechUtterance *utterance;
    NSString *stationTalk = [NSString stringWithFormat:@"Arriving at: %@.", region.identifier];
    utterance = [[AVSpeechUtterance alloc]initWithString:stationTalk];
    utterance.rate = 0.2f;
    utterance.volume = 1.0f;
    utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
    
    [self.speechSynthesizer speakUtterance:utterance];
    
}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    [self.locationManager stopMonitoringForRegion:region];
    self.arrivalMessageLabel.text = @"No alert set";
    [self.stationMessageButton setTitle:[NSString stringWithFormat:@"%@", region.identifier] forState:UIControlStateNormal];
}

-(void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
 
    self.arrivalMessageLabel.text = @"Alert set for:";
    
    [self.stationMessageButton setEnabled:YES];
    [self.stationMessageButton setTitle:[NSString stringWithFormat:@"%@", region.identifier] forState:UIControlStateNormal];
    self.stationMessageButton.titleLabel.textColor = [UIColor redColor];
    
    // have to request state if already in region when app starts monitoring
    [self.locationManager requestStateForRegion:region];
    NSLog(@"Regions being currently monitored after setting alert: %@", [self.locationManager monitoredRegions]);
}

- (void) locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
   NSLog (@"Error: %@", [error localizedDescription]);
    NSLog(@"*****Could not monitor: %@", region.identifier);
}


- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    
    if (state == CLRegionStateInside){
        NSLog(@"is in target region");
        [self locationManager:manager didEnterRegion:region];
        
    }else{
        NSLog(@"is out of target region");
    }
}


- (void)stopRegionMonitoring:(id)sender clearRegions:(CLRegion *)region {
    
    [self.stationMessageButton setEnabled:NO];
    [self.stationMessageButton setTitle:@"Select station on map" forState:UIControlStateNormal];
    
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Clear alerts?" message:@"Press OK to clear alerts" preferredStyle:UIAlertControllerStyleAlert];
    
    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction *action) {
                                                   
                                                   [self.locationManager stopMonitoringForRegion:region];
                                                   [self.locationManager stopUpdatingLocation];
                                                   
                                                   NSLog(@"Region(s) being currently monitored after PRESSING CLEAR: %@", self.locationManager.monitoredRegions);
                                                   
                                                   if (self.stationCircle) {
                                                       [self.mapView removeOverlay:self.stationCircle];
                                                   }
                                                   
                                                   self.arrivalMessageLabel.text = @"No alert set";
                                                   self.stationMessageButton.titleLabel.text = @"Select station on map";
                                                   
                                                   for (id currentAnnotation in self.mapView.annotations) {
                                                       if ([currentAnnotation isKindOfClass:[CHGStation class]]) {
                                                           [self.mapView deselectAnnotation:currentAnnotation animated:YES];
                                                       }
                                                   }
                                               }];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel"
                                                 style:UIAlertActionStyleCancel
                                               handler:^(UIAlertAction *action) {
                                                   return;
                                                }];

    [alertController addAction:cancel];
    [alertController addAction:ok];
    
    
    [self presentViewController:alertController animated:YES completion:nil];
    
}


- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation {
    if (_foundLocationCallback) {
        _foundLocationCallback(userLocation.coordinate);
    }
    _foundLocationCallback = nil;
}

- (void)performAfterFindingLocation:(CHGLocationCallback)callback {
    if (self.mapView.userLocation != nil) {
        if (callback) {
            callback(self.mapView.userLocation.coordinate);
        }
    } else {
        _foundLocationCallback = [callback copy];
    }
}

@end
