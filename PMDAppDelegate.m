//
//  PMDAppDelegate.m
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//

#import "PMDAppDelegate.h"
#import "PMDManager.h"

@implementation PMDAppDelegate

- (void) applicationDidFinishLaunching: (NSNotification *) inNotification
{
	[[PMDManager sharedManager] start];
}

@end
