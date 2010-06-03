//
//  PMDemoAppDelegate.m
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//  Copyright 2010 Griffin Technology, Inc. All rights reserved.
//

#import "PMDAppDelegate.h"
#import "PMDManager.h"

@implementation PMDAppDelegate

@synthesize window;

- (void) applicationDidFinishLaunching: (NSNotification *) inNotification
{
	[[PMDManager sharedManager] start];
}

@end
