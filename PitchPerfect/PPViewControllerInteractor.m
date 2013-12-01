//
//  PPViewControllerInteractor.m
//  PitchPerfect
//
//  Created by Hunter Kyle Gearhart on 2013/11/18.
//  Copyright (c) 2013 Cloud City. All rights reserved.
//

#import "PPViewControllerInteractor.h"

@interface PPViewControllerInteractor () <UIViewControllerAnimatedTransitioning,   UIViewControllerTransitioningDelegate, UIViewControllerInteractiveTransitioning, UIDynamicAnimatorDelegate>

@property (nonatomic, assign, getter = isInteractive) BOOL interactive;
@property (nonatomic, assign, getter = isPresentingLeftView) BOOL presentingLeftView;
@property (nonatomic, assign, getter = isDismissingLeftView) BOOL dismissingLeftView;
@property (nonatomic, assign, getter = isLeftViewPresented) BOOL leftViewPresented;
@property (nonatomic, assign, getter = isRightViewPresented) BOOL rightViewPresented;
@property (nonatomic, assign, getter = isPresentingRightView) BOOL presentingRightView;
@property (nonatomic, assign, getter = isDismissingRightView) BOOL dismissingRightView;
@property (nonatomic, assign, getter = isCompleting) BOOL completing;
@property (nonatomic, assign, getter = isInteractiveTransitionInteracting) BOOL interactiveTransitionInteracting;
@property (nonatomic, assign, getter = isInteractiveTransitionUnderway) BOOL interactiveTransitionUnderway;
@property (nonatomic, strong) id<UIViewControllerContextTransitioning> transitionContext;

@property (nonatomic, strong) UIDynamicAnimator *animator;
@property (nonatomic, strong) UIAttachmentBehavior *attachmentBehaviour;
@property (nonatomic, assign) CGPoint lastKnownVelocity;

@end


@implementation PPViewControllerInteractor

// TODO: Add support for landscape
// TODO: Figure out why dismissals of the right-side view controller aren't bouncy
const BOOL DEBUG_MODE = NO;

#pragma mark - Public Methods

// Initializes the interactor (the mechanism which brings views on and off screen) with a
// parent view which will contain the two views involved in the transition
//
// @param viewController: the UIViewController which will become the interactor's parent view
// @return id: the new interactor with viewController as its parent
- (id)initWithParentViewController:(UIViewController *)viewController {
    if (!(self = [super init])) return nil;
    
    _parentViewController = viewController;
    
    return self;
}


// Function which handles user panning gestures
//
// @param recognizer: an object which recognizes user panning and indicates which edge its on
- (void)userDidPan:(UIScreenEdgePanGestureRecognizer *)recognizer {
    
    if (DEBUG_MODE) {
        NSLog(@"userDidPan");
    }
    
    CGPoint location = [recognizer locationInView:self.parentViewController.view];
    CGPoint velocity = [recognizer velocityInView:self.parentViewController.view];
    
    // Used later to determine if the animation should continue with the transition
    self.lastKnownVelocity = velocity;
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        // Check if we already have an interactive transition underway
        if (self.interactiveTransitionUnderway == NO) {
            // We're being invoked via a gesture recognizer – we are necessarily interactive
            self.interactive = YES;
            // If we're not presenting either the left or right view, bring the appropriate one onscreen
            if (!self.leftViewPresented && !self.rightViewPresented) {
                // The side of the screen we're panning from determines whether this is a presentation left or right
                UIViewController *viewController;
                if (location.x < CGRectGetMidX(recognizer.view.bounds)) {
                    self.presentingLeftView = YES;
                    viewController = [[PPSettingsScreenViewController alloc] initWithPanTarget:self];
                    viewController.modalPresentationStyle = UIModalPresentationCustom;
                    viewController.transitioningDelegate = self;
                    [self.parentViewController presentViewController:viewController animated:YES completion:nil];
                } else if(location.x > CGRectGetMidX(recognizer.view.bounds)) {
                    self.presentingRightView = YES;
                    viewController = [[PPGameScreenViewController alloc] initWithPanTarget:self];
                    viewController.modalPresentationStyle = UIModalPresentationCustom;
                    viewController.transitioningDelegate = self;
                    [self.parentViewController presentViewController:viewController animated:YES completion:nil];
                }
            // Only perform a transition if it's a dismissal of the left or right view
            } else {
                // Perform the appropriate dismissal given the view being presented
                if(self.leftViewPresented && location.x > CGRectGetMidX(recognizer.view.bounds)) {
                    self.dismissingLeftView = YES;
                    [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
                } else if(self.rightViewPresented && location.x < CGRectGetMidX(recognizer.view.bounds)) {
                    self.dismissingRightView = YES;
                    [self.parentViewController dismissViewControllerAnimated:YES completion:nil];
                }

            }
        }
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        // Determine our ratio between the left edge and the right edge. This means our dismissal will go from 1 to 0.
        CGFloat screenWidth = CGRectGetWidth(self.parentViewController.view.bounds);
        CGFloat ratio = location.x / screenWidth;
        // Invert the ratio if we're working right-to-left
        if(self.presentingRightView || self.dismissingRightView) {
            ratio = 1 - ratio;
        }
        [self updateInteractiveTransition:ratio];
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        // Depending on our state and the velocity, determine whether to cancel or complete the transition.
        if (self.interactiveTransitionInteracting) {
            if (self.presentingLeftView || self.dismissingRightView) {
                if (velocity.x > 0) {
                    [self finishInteractiveTransition];
                } else {
                    [self cancelInteractiveTransition];
                }
            } else if(self.presentingRightView || self.dismissingLeftView) {
                if (velocity.x < 0) {
                    [self finishInteractiveTransition];
                } else {
                    [self cancelInteractiveTransition];
                }
            }
        }
    }
}

#pragma mark - Private Methods

// Ensures that the transition's animation ends at the proper position with the new UIViewController taking
// up the screen
//
// @param endFrame: where the appropriate UIViewController would end up if the transition were done to
// completion
- (void)ensureSimulationCompletesWithDesiredEndFrame:(CGRect)endFrame {
    
    if (DEBUG_MODE) {
        NSLog(@"ensureSimulationCompletesWithDesiredEndFrame");
    }
    
    // Take a "snapshot" of the transitionContext when this method is first invoked. We'll compare it to self.transitionContext
    // When the dispatch_after block is invoked.
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    
    // Grab the two UIViewControllers involved in the transition
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    // We need to make sure that our transition completes at some point.
    double delayInSeconds = 0.5f;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        // If we still have an animator, we're still animating, so we need to complete our transition immediately.
        id<UIViewControllerContextTransitioning> blockContext = self.transitionContext;
        UIDynamicAnimator *blockAnimator = self.animator;
        if (blockAnimator && blockContext == transitionContext) {
            BOOL presentingLeft = self.presentingLeftView;
            BOOL presentingRight = self.presentingRightView;
            BOOL dismissingLeft = self.dismissingLeftView;
            BOOL dismissingRight = self.dismissingRightView;
            
            // Needs to be given correct parameter as this is the method which changes the parent view
            // controllers presentingViewController attributes, which is vital to the transitioner's state
            [transitionContext completeTransition:self.completing];
            
            if(presentingLeft || presentingRight) {
                toViewController.view.frame = endFrame;
            } else if(dismissingLeft || dismissingRight) {
                fromViewController.view.frame = endFrame;
            }

        }
    });
    
}

#pragma mark - UIViewControllerTransitioningDelegate Methods

// Returns self as the delegate for presentation animations of UIViews which utilize the delegate methods implemented below
//
// @param presented: the UIViewController which is about to be brought onscreen
// @param presenting: the UIViewController which is currently onscreen
// @param source: the view controller whose presentViewController:animated:completion: method was called.
// @return id: the object implementing UIViewControllerAnimatedTransitioning which is responsible for presentation animations
- (id <UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    return self;
}

// Returns self as the delegate for dismissal animations of UIViews which utilize the delegate methods implemented below
//
// @param dismissed: the UIViewController which is being dismissed
// @return id: the object implementing UIViewControllerAnimatedTransitioning which is responsible for dismissal animations
- (id <UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    return self;
}

// If the interactor recognizes itself as receiving interactions from the user, return self as delegate for keeping track of user interaction during the presentation of a view
//
// @param animator: the animator which would conduct the transition non-interactively
// @return id: the object implementing UIViewControllerInteractiveTransitioning which will allow interaction during the transition
- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id <UIViewControllerAnimatedTransitioning>)animator {
    // Return nil if we are not interactive
    if (self.interactive) {
        return self;
    }
    return nil;
}

// If the interactor recognizes itself as receiving interactions from the user, return self as delegate for keeping track of user interaction during the dismissal of a view
//
// @param animator: the animator which would conduct the transition non-interactively
// @return id: the object implementing UIViewControllerInteractiveTransitioning which will allow interaction during the transition
- (id <UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id <UIViewControllerAnimatedTransitioning>)animator {
    // Return nil if we are not interactive
    if (self.interactive) {
        return self;
    }
    
    return nil;
}

#pragma mark - UIViewControllerAnimatedTransitioning Methods

// Called upon the completion of user interaction which is causing a transition to happen between
// UIViews
//
// @param transitionCompleted: a boolean indicating if the new UIView was brought completely onscreen
- (void)animationEnded:(BOOL)transitionCompleted {
    
    if (DEBUG_MODE) {
        NSLog(@"animationEnded");
    }
    
    // Grab the transition context and the UIViews contained within
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    // Re-enable user interaction on both now that the transition was completed or cancelled
    fromViewController.view.userInteractionEnabled = YES;
    toViewController.view.userInteractionEnabled = YES;
    
    // Reset to our default state
    self.interactive = NO;
    self.presentingLeftView = NO;
    self.presentingRightView = NO;
    self.dismissingLeftView = NO;
    self.dismissingRightView = NO;
    self.transitionContext = nil;
    self.completing = NO;
    self.interactiveTransitionInteracting = NO;
    self.interactiveTransitionUnderway = NO;
    
    // Remove all dynamic behaviors (gravity, collision) from the UIViews
    [self.animator removeAllBehaviors], self.animator.delegate = nil, self.animator = nil;
    
}

// If the interactor recognizes itself as receiving interactions from the user, return self as delegate for keeping track of user interaction during the dismissal of a view
//
// @param animator: the animator which would conduct the transition non-interactively
// @return transitionDuration: a NSTimeInterval (double typedef) this is the desired time for the animation
// to take ignoring user interaction
- (NSTimeInterval)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    // Used as an upper-bounds to the UIKit Dynamics simulation elapsedTime
    return 2.0f;
}

// Actually performs the transition between the two views involved. User interactivity is added during
// this step by utilizing a UIDynamicAnimator which we define behavior for.
//
// @param transitionContext: contains information on the two views involved in the transition
- (void)animateTransition:(id <UIViewControllerContextTransitioning>)transitionContext {
    
    if (DEBUG_MODE) {
        NSLog(@"animateTransition");
    }
    self.transitionContext = transitionContext;
    
    if (self.interactive) {
        // nop as per documentation
    } else {
        // Guaranteed to complete since this is a non-interactive transition
        self.completing = YES;
        
        // Grab information on the two UIViewControllers involved
        UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
        UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
        
        // Initialize frames of where the UIView will start and end its transition
        CGRect startFrame = [[transitionContext containerView] bounds];
        CGRect endFrame = [[transitionContext containerView] bounds];
        
        // Initializes a UIDynamicAnimator which will handle dynamic behavior that is delegated to
        // the interactor
        self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:transitionContext.containerView];
        self.animator.delegate = self;
        
        if (self.presentingLeftView || self.presentingRightView) {
            // The order of these matters – determines the view hierarchy order.
            [transitionContext.containerView addSubview:fromViewController.view];
            [transitionContext.containerView addSubview:toViewController.view];
            
            UICollisionBehavior *collisionBehaviour = [[UICollisionBehavior alloc] initWithItems:@[toViewController.view]];
            UIGravityBehavior *gravityBehaviour = [[UIGravityBehavior alloc] initWithItems:@[toViewController.view]];
            
            // Depending on what we're bringing onscreen, the UIView will begin offscreen left or right
            // Also, add the appropriate collision and gravity behavior depending on the side of the UIView
            // we're bringing onscreen
            if (self.presentingLeftView) {
                startFrame.origin.x -= CGRectGetWidth([[transitionContext containerView] bounds]);
                [collisionBehaviour setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0, -CGRectGetWidth(transitionContext.containerView.bounds), 0, 0)];
                gravityBehaviour.gravityDirection = CGVectorMake(5.0f, 0.0f);
            } else if(self.presentingRightView) {
                startFrame.origin.x += CGRectGetWidth([[transitionContext containerView] bounds]);
                [collisionBehaviour setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0, 0, 0, CGRectGetWidth(transitionContext.containerView.bounds))];
                gravityBehaviour.gravityDirection = CGVectorMake(-5.0f, 0.0f);

            }
            toViewController.view.frame = startFrame;
            
            [self.animator addBehavior:collisionBehaviour];
            [self.animator addBehavior:gravityBehaviour];
        } else {
            // We must be dismissing the left or right-hand view
            [transitionContext.containerView addSubview:toViewController.view];
            [transitionContext.containerView addSubview:fromViewController.view];
            
            // Depending on what we're taking offscreen, the end frame will be offscreen left or right
            if(self.dismissingLeftView) {
                endFrame.origin.x -= CGRectGetWidth(self.transitionContext.containerView.bounds);
            } else if(self.dismissingRightView) {
                endFrame.origin.x += CGRectGetWidth(self.transitionContext.containerView.bounds);
            }
            
            fromViewController.view.frame = startFrame;
            
            UICollisionBehavior *collisionBehaviour = [[UICollisionBehavior alloc] initWithItems:@[fromViewController.view]];
            UIGravityBehavior *gravityBehaviour = [[UIGravityBehavior alloc] initWithItems:@[fromViewController.view]];
            
            // Set collisions and gravity to coincide with our dismissal direction
            if(self.dismissingLeftView) {
                [collisionBehaviour setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0, -CGRectGetWidth(transitionContext.containerView.bounds), 0, 0)];
                gravityBehaviour.gravityDirection = CGVectorMake(-5.0f, 0.0f);
            } else if(self.dismissingRightView) {
                [collisionBehaviour setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0, 0, 0, CGRectGetWidth(transitionContext.containerView.bounds))];
                gravityBehaviour.gravityDirection = CGVectorMake(5.0f, 0.0f);
            }
            
            [self.animator addBehavior:collisionBehaviour];
            [self.animator addBehavior:gravityBehaviour];
        }
        
        [self ensureSimulationCompletesWithDesiredEndFrame:endFrame];
    }
}

#pragma mark - UIViewControllerInteractiveTransitioning Methods

// Initiates an interactive transition adding in different dynamic behaviors to the UIViews being
// transitioned between
//
// @param transitionContext: the transitionContext which contains information of the two views involved
// in the transition
-(void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    
    if (DEBUG_MODE) {
        NSLog(@"startInteractiveTransition");
    }
    
    NSAssert(self.animator == nil, @"Duplicating animators – likely two presentations running concurrently.");
    
    // Grab the transition context and indicate that we're using user interaction to perform a transition
    self.transitionContext = transitionContext;
    self.interactiveTransitionInteracting = YES;
    self.interactiveTransitionUnderway = YES;
    
    // Get information of the two UIViewControllers involved in the transition
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    // Disable user interaction on the view which will be covered up
    fromViewController.view.userInteractionEnabled = NO;
    
    CGRect frame = [[transitionContext containerView] bounds];
    
    // Despite if we're displaying the left-view or right-view we still want the toViewController
    // to be displayed on top
    if (self.dismissingLeftView || self.dismissingRightView) {
        // If dismissing a view put it underneath in the context
        [transitionContext.containerView addSubview:toViewController.view];
        [transitionContext.containerView addSubview:fromViewController.view];
    } else if (self.presentingLeftView || self.presentingRightView) {
        // If displaying a view, place it on top of the original in the context
        [transitionContext.containerView addSubview:fromViewController.view];
        [transitionContext.containerView addSubview:toViewController.view];
    }
    
    // Depending on if we're displaying left or right, have the views frame be offscreen in the
    // correct direction
    if(self.presentingLeftView) {
        frame.origin.x -= CGRectGetWidth([[transitionContext containerView] bounds]);
    } else if(self.presentingRightView) {
        frame.origin.x += CGRectGetWidth([[transitionContext containerView] bounds]);
    }
    
    // Initialize the toViewControllers frame in the proper direction
    toViewController.view.frame = frame;
    
    // Create an animator to handle the dynamic behavior of the objects contained in the view
    self.animator = [[UIDynamicAnimator alloc] initWithReferenceView:transitionContext.containerView];
    // Set the interactor as the handler for all animations occuring in the view
    self.animator.delegate = self;
    
    // The view will be a Dynamic Item so that it can bounce and what not
    id <UIDynamicItem> dynamicItem;
    
    // If we're bringing in a view from the left or right, that view will be dynamic
    // Otherwise we're returning to the original view and that one must be dynamic
    if (self.dismissingLeftView || self.dismissingRightView) {
        dynamicItem = fromViewController.view;
        // If dismissing the left-view, anchor the original view right
        if (self.dismissingLeftView) {
            self.attachmentBehaviour = [[UIAttachmentBehavior alloc] initWithItem:dynamicItem attachedToAnchor:CGPointMake(CGRectGetWidth(transitionContext.containerView.bounds), CGRectGetMidY(transitionContext.containerView.bounds))];
        // Else we're dismissing the right view so the original should be anchored left
        } else if(self.dismissingRightView) {
            self.attachmentBehaviour = [[UIAttachmentBehavior alloc] initWithItem:dynamicItem attachedToAnchor:CGPointMake(0.0f, CGRectGetMidY(transitionContext.containerView.bounds))];
        }
    } else if (self.presentingLeftView || self.presentingRightView) {
        dynamicItem = toViewController.view;
        // The anchor of the view will be left or right depending on the side of the view being brought in
        if(self.presentingLeftView) {
            self.attachmentBehaviour = [[UIAttachmentBehavior alloc] initWithItem:dynamicItem attachedToAnchor:CGPointMake(0.0f, CGRectGetMidY(transitionContext.containerView.bounds))];
        } else if(self.presentingRightView) {
            self.attachmentBehaviour = [[UIAttachmentBehavior alloc] initWithItem:dynamicItem attachedToAnchor:CGPointMake(CGRectGetWidth(transitionContext.containerView.bounds), CGRectGetMidY(transitionContext.containerView.bounds))];
        }
    }
    
    
    // We're setting a collisionBehavior here so that the view collides with the opposite edge of the
    // screen. The insets indicate that the view will crash into a boundary the width of the container
    // view to the right or left depending on the view we're displaying.
    UICollisionBehavior *collisionBehaviour = [[UICollisionBehavior alloc] initWithItems:@[dynamicItem]];
    if(self.dismissingRightView || self.presentingRightView) {
        [collisionBehaviour setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0, 0, 0, CGRectGetWidth(transitionContext.containerView.bounds))];
    } else if(self.dismissingLeftView || self.presentingLeftView) {
        [collisionBehaviour setTranslatesReferenceBoundsIntoBoundaryWithInsets:UIEdgeInsetsMake(0, -CGRectGetWidth(transitionContext.containerView.bounds), 0, 0)];
    }
    
    [self.animator addBehavior:collisionBehaviour];
    [self.animator addBehavior:self.attachmentBehaviour];
}

// Gives the interactive transition a predefined completion time of 1 second
- (CGFloat)completionSpeed {
    return 2.0f;
}

// Makes the transition begin and end slow and smooth
- (UIViewAnimationCurve)completionCurve {
    return UIViewAnimationCurveEaseInOut;
}

#pragma mark - UIPercentDrivenInteractiveTransition Overridden Methods

// Constantly called during the interactive transition to update the current progress
//
// @param percentComplete: the percentage complete, percentage distance away from the endframe
// position of the transition
- (void)updateInteractiveTransition:(CGFloat)percentComplete {
    if (DEBUG_MODE) {
        NSLog(@"updateInteractiveTransition");
    }
    CGFloat viewWidth = CGRectGetWidth(self.transitionContext.containerView.bounds);
    if (self.presentingLeftView || self.dismissingLeftView) {
        self.attachmentBehaviour.anchorPoint = CGPointMake(viewWidth * percentComplete, CGRectGetMidY(self.transitionContext.containerView.bounds));
    } else if(self.presentingRightView || self.dismissingRightView) {
        self.attachmentBehaviour.anchorPoint = CGPointMake(viewWidth - (viewWidth * percentComplete), CGRectGetMidY(self.transitionContext.containerView.bounds));
    }
}

// Called if the users interactions indicate that the interactive transition should indeed finish.
// In this application's case, if the velocity towards completion is positive.
- (void)finishInteractiveTransition {
    if (DEBUG_MODE) {
            NSLog(@"finishInteractiveTransition");
    }
    
    self.interactiveTransitionInteracting = NO;
    self.completing = YES;
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    
    [self.animator removeBehavior:self.attachmentBehaviour];
    
    // Grab the two UIViewControllers involved in the transition
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    // The end result of the transition should fill the screen
    CGRect endFrame = transitionContext.containerView.bounds;
    
    // Applies gravity to the view being brought onscreen in the correct direction to force completion
    id<UIDynamicItem> dynamicItem;
    CGFloat gravityXComponent = 0.0f;
    
    if (self.presentingLeftView) {
        dynamicItem = toViewController.view;
        gravityXComponent = 5.0f;
    } else if(self.presentingRightView) {
        dynamicItem = toViewController.view;
        gravityXComponent = -5.0f;
    } else if(self.dismissingLeftView) {
        dynamicItem = fromViewController.view;
        gravityXComponent = -5.0f;
        endFrame.origin.x -= CGRectGetWidth(endFrame);
    } else if(self.dismissingRightView) {
        dynamicItem = fromViewController.view;
        gravityXComponent = 5.0f;
        endFrame.origin.x += CGRectGetWidth(endFrame);
    }
    
    // Actually applies the gravity and a push to the view being brought onscreen to finish the transition
    UIGravityBehavior *gravityBehaviour = [[UIGravityBehavior alloc] initWithItems:@[dynamicItem]];
    gravityBehaviour.gravityDirection = CGVectorMake(gravityXComponent, 0.0f);
    UIPushBehavior *pushBehaviour = [[UIPushBehavior alloc] initWithItems:@[dynamicItem] mode:UIPushBehaviorModeInstantaneous];
    // The push doesn not need to be tailored to each type of transition because the velocity
    // will be positive or negative at the appropriate times
    pushBehaviour.pushDirection = CGVectorMake(self.lastKnownVelocity.x / 10.0f, 0.0f);
    
    // Now that we're done with the transition for sure, ensure that our interactor has the right
    // state information
    if(self.presentingLeftView) {
        self.leftViewPresented = YES;
    } else if (self.presentingRightView) {
        self.rightViewPresented = YES;
    } else if (self.dismissingRightView) {
        self.rightViewPresented = NO;
    } else if (self.dismissingLeftView) {
        self.leftViewPresented = NO;
    }
    
    [self.animator addBehavior:gravityBehaviour];
    [self.animator addBehavior:pushBehaviour];
    [self ensureSimulationCompletesWithDesiredEndFrame:endFrame];
}

// Called if the users interactions indicate that the interactive transition should indeed be cancelled.
// In this application's case, if the velocity towards completion is negative.
- (void)cancelInteractiveTransition {
    if (DEBUG_MODE) {
        NSLog(@"cancelInteractiveTransition");
    }
    // Grab the transition context and indicate that we're no longer interactive
    self.interactiveTransitionInteracting = NO;
    id<UIViewControllerContextTransitioning> transitionContext = self.transitionContext;
    
    [self.animator removeBehavior:self.attachmentBehaviour];
    
    // Grab the two UIViews involved in the transition
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    CGRect endFrame = transitionContext.containerView.bounds;
    
    id<UIDynamicItem> dynamicItem;
    CGFloat gravityXComponent = 0.0f;
    
    // This actually works oppositely than it normally does because we're cancelling the
    // transition midway
    if (self.presentingLeftView) {
        dynamicItem = toViewController.view;
        gravityXComponent = -5.0f;
        endFrame.origin.x -= CGRectGetWidth(endFrame);
    } else if(self.presentingRightView) {
        dynamicItem = toViewController.view;
        gravityXComponent = 5.0f;
        endFrame.origin.x += CGRectGetWidth(endFrame);
    } else if(self.dismissingRightView) {
        dynamicItem = fromViewController.view;
        gravityXComponent = -5.0f;
        endFrame.origin.x = 0.0;
    } else if(self.dismissingLeftView){
        dynamicItem = fromViewController.view;
        gravityXComponent = 5.0f;
        endFrame.origin.x = 0.0;
    }
    
    UIGravityBehavior *gravityBehaviour = [[UIGravityBehavior alloc] initWithItems:@[dynamicItem]];
    gravityBehaviour.gravityDirection = CGVectorMake(gravityXComponent, 0.0f);
    
    // The push doesn't not need to be tailored to each type of transition because the velocity
    // will be positive or negative at the appropriate times
    UIPushBehavior *pushBehaviour = [[UIPushBehavior alloc] initWithItems:@[dynamicItem] mode:UIPushBehaviorModeInstantaneous];
    pushBehaviour.pushDirection = CGVectorMake(self.lastKnownVelocity.x / 10.0f, 0.0f);
    
    [self.animator addBehavior:gravityBehaviour];
    [self.animator addBehavior:pushBehaviour];
    
    [self ensureSimulationCompletesWithDesiredEndFrame:endFrame];
}

#pragma mark - UIDynamicAnimatorDelegate Methods

- (void)dynamicAnimatorDidPause:(UIDynamicAnimator*)animator {
    if (DEBUG_MODE) {
        NSLog(@"dynamicAnimatorDidPause");
    }
    // We need this check to determine if the user is still interacting with the transition (ie: they stopped moving their finger)
    if (!self.interactiveTransitionInteracting) {
        [self.transitionContext completeTransition:self.completing];
    }
}

// Gives a simple print-out of the state of the interactor for debugging purposes
- (void)printState {
    NSString *stringFormat = @"%@ %@";
    NSString *value = (self.presentingLeftView) ? @"YES" : @"NO";
    NSLog(stringFormat, @"presentingLeftView:", value);
    value = (self.presentingRightView) ? @"YES" : @"NO";
    NSLog(stringFormat, @"presentingRightView:", value);
    value = (self.leftViewPresented) ? @"YES" : @"NO";
    NSLog(stringFormat, @"leftViewPresented:", value);
    value = (self.rightViewPresented) ? @"YES" : @"NO";
    NSLog(stringFormat, @"rightViewPresented:", value);
    value = (self.dismissingLeftView) ? @"YES" : @"NO";
    NSLog(stringFormat, @"dismissingLeftView:", value);
    value = (self.dismissingRightView) ? @"YES" : @"NO";
    NSLog(stringFormat, @"dismissingRightView:", value);
    value = (self.interactiveTransitionInteracting) ? @"YES" : @"NO";
    NSLog(stringFormat, @"interactiveTransitionInteracting:", value);
    value = (self.interactiveTransitionUnderway) ? @"YES" : @"NO";
    NSLog(stringFormat, @"interactiveTransitionUnderway:", value);
    value = self.parentViewController.presentedViewController.title;
    NSLog(stringFormat, @"NameOfPresentedController:", value);
}

@end