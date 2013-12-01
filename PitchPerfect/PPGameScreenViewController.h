//
//  PPGameScreenViewController.h
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/18.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "PPMenuViewControllerPanTarget.h"
 
@interface PPGameScreenViewController : UIViewController

-(id)initWithPanTarget:(id<PPMenuViewControllerPanTarget>)panTarget;

@property (nonatomic, readonly) id<PPMenuViewControllerPanTarget> panTarget;

@end
