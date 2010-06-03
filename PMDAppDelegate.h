//
//  PMDemoAppDelegate.h
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//  Copyright 2010 Griffin Technology, Inc. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PMDAppDelegate : NSObject <NSApplicationDelegate>
{
    NSWindow	*_window;
}

@property (assign) IBOutlet NSWindow *window;

@end
