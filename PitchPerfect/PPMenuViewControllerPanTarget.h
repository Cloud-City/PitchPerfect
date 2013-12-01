//
//  PPMenuViewControllerPanTarget.h
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/19.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import <Foundation/Foundation.h>

// A protocol which must be implemented by each UIViewController class
// that will be draggable onscreen from the home screen
@protocol PPMenuViewControllerPanTarget <NSObject>

// Each of these UIViewControllers must have defined behavior for when a user begins to
// drag across the screen
-(void)userDidPan:(UIScreenEdgePanGestureRecognizer *)gestureRecognizer;

@end
