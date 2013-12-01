//
//  PPGameScreenViewController.m
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/18.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import "PPGameScreenViewController.h"

@interface PPGameScreenViewController ()

@end

@implementation PPGameScreenViewController

// Initialize the game UIViewController with a panTarget which will be the interactor which
// is handling the panning gestures of the user
//
// @param panTarget: an object which implements the PPMenuViewControllerPanTarget custom protocol
// which simply requires that the object have pre-defined behavior for panning gestures by the user
-(id)initWithPanTarget:(id<PPMenuViewControllerPanTarget>)panTarget
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = @"GameScreenViewController";
        _panTarget = panTarget;
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Give the game screen a green background
    self.view.backgroundColor = [UIColor greenColor];
    
    // Adds and centers the Settings label to the center of the UIView
    UILabel *label = [[UILabel alloc] initWithFrame:self.view.bounds];
    label.text = @"GAME!";
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
    
    // Creates a gesture recognizer which delegates to the panTarget for defined behavior
    UIScreenEdgePanGestureRecognizer *gestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self.panTarget action:@selector(userDidPan:)];
    gestureRecognizer.edges = UIRectEdgeLeft;
    [self.view addGestureRecognizer:gestureRecognizer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end
