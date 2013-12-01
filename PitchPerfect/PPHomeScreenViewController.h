//
//  PPHomeScreenViewController.h
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/18.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "PPMenuViewControllerPanTarget.h"
#import "PPViewControllerInteractor.h"

@interface PPHomeScreenViewController : UIViewController

@property (nonatomic, strong) id<PPMenuViewControllerPanTarget> menuInteractor;

@end
