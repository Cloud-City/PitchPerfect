//
//  PPHomeScreenViewController.m
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/18.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import "PPHomeScreenViewController.h"

@interface PPHomeScreenViewController ()

@end

@implementation PPHomeScreenViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Set background to greyish color
    self.view.backgroundColor = [UIColor grayColor];
    
    // Create a menu interactor which will be responsible for interactive transitions between views
    self.menuInteractor = [[PPViewControllerInteractor alloc] initWithParentViewController:self];
    
    // Creates a gesture recognizer and delegates behavior to the panTarget (the menuInteractor)
    UIScreenEdgePanGestureRecognizer *leftEdgeGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self.menuInteractor action:@selector(userDidPan:)];
    leftEdgeGestureRecognizer.edges = UIRectEdgeLeft;
    
    // Adds the gesture recognizer to the view
    [self.view addGestureRecognizer:leftEdgeGestureRecognizer];
    
    // Creates a gesture recognizer and delegates behavior to the panTarget (the menuInteractor)
    UIScreenEdgePanGestureRecognizer *rightEdgeGestureRecognizer = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self.menuInteractor action:@selector(userDidPan:)];
    rightEdgeGestureRecognizer.edges = UIRectEdgeRight;
    
    // Adds the gesture recognizer to the view
    [self.view addGestureRecognizer:rightEdgeGestureRecognizer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

@end
