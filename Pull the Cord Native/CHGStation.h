//
//  CHGStation.h
//  Pull the Cord Native
//
//  Created by Charles Grier on 1/27/15.
//  Copyright (c) 2015 Grier Mobile Development. All rights reserved.
//

#import <Foundation/Foundation.h>
@import MapKit;

@interface CHGStation : NSObject <MKAnnotation, CLLocationManagerDelegate>

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *stationName;
@property (nonatomic, copy) NSString *lineName;
@property (nonatomic, copy) NSString *radius;
@property (nonatomic, assign) double geofenceRadius;
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@end
