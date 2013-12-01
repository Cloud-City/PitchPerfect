//
//  PPViewControllerInteractor.h
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/18.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPSettingsScreenViewController.h"
#import "PPGameScreenViewController.h"

@interface PPViewControllerInteractor : UIPercentDrivenInteractiveTransition <PPMenuViewControllerPanTarget>

- (id)initWithParentViewController:(UIViewController *)viewController;

@property (nonatomic, readonly) UIViewController *parentViewController;

@end