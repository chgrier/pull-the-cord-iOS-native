//
//  CHGAppDelegate.h
//  Pull the Cord Native
//
//  Created by Charles Grier on 1/27/15.
//  Copyright (c) 2015 Grier Mobile Development. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "CHGMainViewController.h"

@interface CHGAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) CHGMainViewController *viewController;

@end

