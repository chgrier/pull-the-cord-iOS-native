//
//  CHGMainViewController.m
//  Pull the Cord Native
//
//  Created by Charles Grier on 1/27/15.
//  Copyright (c) 2015 Grier Mobile Development. All rights reserved.
//

#import "CHGMainViewController.h"
@import CoreLocation;
#import <MapKit/MapKit.h>
#import "CHGStation.h"
@import AVFoundation;

@interface CHGMainViewController () <CLLocationManagerDelegate, MKMapViewDelegate>
{
    BOOL _didStartMonitoringRegion;
}


@property (strong, nonatomic) NSMutableArray *stations;
@property (strong, nonatomic) MKPolyline *mapPolyline;
@property (strong, nonatomic) MKCircle *stationCircle;
@property (strong, nonatomic) AVSpeechSynthesizer *speechSynthesizer;

@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UILabel *stationMessageLabel;
@property (weak, nonatomic) IBOutlet UILabel *arrivalMessageLabel;

@end

@implementation CHGMainViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
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
    MKCoordinateSpan span = MKCoordinateSpanMake(0.3, 0.3); // one degree of latitude is 69 miles; longitude varies
    MKCoordinateRegion regionToDisplay = MKCoordinateRegionMake(center, span);
    [self.mapView setRegion:regionToDisplay animated:NO];
    
   // MKCircle *circle = [MKCircle circleWithCenterCoordinate:center radius:1000];
   // [self.mapView addOverlay:circle];
    
    [self.mapView addOverlay:self.mapPolyline];
    [self.mapView addAnnotations:self.stations];
    
    /* keep UIAlerts from showing when app is is in background
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(didEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
*/
    
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
            UIImageView *myCustomImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"trolleyLogo.jpg"]];
            view.image = [UIImage imageNamed:@"busStop.png"];
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
    
        NSString *title = @"Set alert for this station";
        NSString *message = [NSString stringWithFormat:@"Get notified when you are approaching the %@", selectedStation.title];
        
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleActionSheet];
        
        UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            NSLog(@"Alert Action: Cancel pressed");
        }];
        
        UIAlertAction *setAlert = [UIAlertAction actionWithTitle:@"Set Alert" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            
            [self monitorSelectedStation:selectedStation];
            [self selectStationAndZoom:selectedStation];
            
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
        
    /* create an action sheet
    UIAlertController *sheet = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    
    // add button on action sheet to set alert for selected station
    [sheet addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"Set alert for this station"]
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction *action) {
                          
                          [self monitorSelectedStation:selectedStation];
                          
                        // remove radius circle if one already exists
                          if (self.stationCircle) {
                              [self.mapView removeOverlay:self.stationCircle];
                              
                          }
                          self.stationCircle = [MKCircle circleWithCenterCoordinate:selectedStation.coordinate radius:[selectedStation.radius floatValue]];
                          self.stationCircle.title = @"%@", [NSString stringWithFormat:@"%@", selectedStation.title];
                          
                          [self.mapView addOverlay:self.stationCircle];
                          
                          MKCoordinateSpan span = MKCoordinateSpanMake(0.02, 0.02); // one degree of latitude is 69 miles; longitude varies
                          MKCoordinateRegion regionToDisplay = MKCoordinateRegionMake(self.stationCircle.coordinate, span);
                          [self.mapView setRegion:regionToDisplay animated:YES];
                          
                        }]];

   
       [sheet addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    
    [self presentViewController:sheet animated:YES completion:nil];
    */
}
}

-(void)selectStationAndZoom:(CHGStation *)selectedStation {
    
    if (self.stationCircle) {
        [self.mapView removeOverlay:self.stationCircle];
    }
    
    self.stationCircle = [MKCircle circleWithCenterCoordinate:selectedStation.coordinate radius:[selectedStation.radius floatValue]];
    self.stationCircle.title = @"%@", [NSString stringWithFormat:@"%@", selectedStation.title];
    
    [self.mapView addOverlay:self.stationCircle];
    
    MKCoordinateSpan span = MKCoordinateSpanMake(0.02, 0.02); // one degree of latitude is 69 miles; longitude varies
    MKCoordinateRegion regionToDisplay = MKCoordinateRegionMake(self.stationCircle.coordinate, span);
    [self.mapView setRegion:regionToDisplay animated:YES];
    
    
}

#pragma mark - Geofencing Methods


// start monitoring for region
-(void)monitorSelectedStation:(CHGStation *)station
{
    //[self.locationManager startUpdatingLocation];
    [self.locationManager startMonitoringForRegion:[[CLCircularRegion alloc]initWithCenter:station.coordinate radius:700.0 identifier:station.title]];
    
    
    NSLog(@"Station being monitored: %@", station.title);
    // notify user on interface which station is being monitored
    
    /*
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert set!"
                                                    message:[NSString stringWithFormat:@"You will be notified when approaching %@", station.title]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    
    [alert show];
    */
    
    [self showAlertforRegionMonitoring:station];
}

// alert view for region monitoring
-(void)showAlertforRegionMonitoring:(CHGStation *)station {
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Alert set!"
                                                    message:[NSString stringWithFormat:@"You will be notified when approaching %@", station.title]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    
    [alert show];

    
   // [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification* notification){
   //     [alert ];
    //}];
}

// delegates for region monitoring

-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    //[self.locationManager requestStateForRegion:region];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Arriving at your station"
                                                    message:[NSString stringWithFormat:@"You are approaching %@", region.identifier]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    
    NSLog(@"You just enetered geofence %@",region.identifier);
    self.arrivalMessageLabel.text = @"Arriving at:";
    self.stationMessageLabel.text = [NSString stringWithFormat:@"%@", region.identifier];
    
    self.speechSynthesizer = [[AVSpeechSynthesizer alloc]init];
    static AVSpeechUtterance *utterance;
    
    NSString *stationTalk = [NSString stringWithFormat:@"Arriving at: %@.", region.identifier];
    utterance = [[AVSpeechUtterance alloc]initWithString:stationTalk];
    utterance.rate = 0.2f;
    utterance.volume = 1.0f;
    //utterance.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"en-US"];
    
    [self.speechSynthesizer speakUtterance:utterance];

}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    [self.locationManager stopMonitoringForRegion:region];
    self.arrivalMessageLabel.text = @"No alert set";
    self.stationMessageLabel.text = [NSString stringWithFormat:@"Select a station to set an alert%@", region.identifier];
}


-(void)locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region {
    
    NSLog(@"Now monitoring for %@ with radius of %f meters", region.identifier, region.radius);
    
    self.arrivalMessageLabel.text = @"Alert set for:";
    self.stationMessageLabel.text = [NSString stringWithFormat:@"%@", region.identifier];
    
    // have to request state if already in region when app strats monitoring
    [self.locationManager requestStateForRegion:region];
    //[self locationManager:manager didEnterRegion:region];
}


- (void) locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
   NSLog (@"Error: %@", [error localizedDescription]);
}


- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    
    if (state == CLRegionStateInside){
        NSLog(@"is in target region");
        [self locationManager:manager didEnterRegion:region];
    }else{
        NSLog(@"is out of target region");
    }
}

@end