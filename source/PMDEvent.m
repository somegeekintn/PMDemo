//
//  PMDEvent.m
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//  Copyright 2010 Griffin Technology, Inc. All rights reserved.
//

#import "PMDEvent.h"


static UInt64	sActiveEventID = 0;

@implementation PMDEvent

@synthesize rawValue = _rawValue;
@synthesize scaledValue = _scaledValue;
@synthesize rps = _rps;
@synthesize validRPS = _validRPS;
@synthesize eventID = _eventID;
@synthesize deviceLocation = _deviceLocation;
@synthesize type = _type;
@synthesize previousType = _previousType;
@synthesize modifiers = _modifiers;
@synthesize processedOffset = _processedOffset;
@synthesize eventTime = _eventTime;

+ (NSString *) stringForType: (NSUInteger) inType
{
	NSString	*eventName = nil;
	
	switch (inType) {
		case ePowerMateAction_ButtonPress:		eventName = @"Press       ";	break;
		case ePowerMateAction_ButtonRelease:	eventName = @"Release     ";	break;
		case ePowerMateAction_RotateLeft:		eventName = @"Rotate Left ";	break;
		case ePowerMateAction_RotateRight:		eventName = @"Rotate Right";	break;
		case ePowerMateAction_ButtonLongPress:	eventName = @"Long Press";		break;
		default:								eventName = @"Unknown     ";	break;
	}
	
	return eventName;
}

+ (NSString *) stringForModifiers: (NSUInteger) inModifiers
{
	return [NSString stringWithFormat: @"%c%c%c%c%c",
		inModifiers & ePowerMateModifier_Shift		? 'S' : '-',
		inModifiers & ePowerMateModifier_Control	? 'T' : '-',
		inModifiers & ePowerMateModifier_Option		? 'O' : '-',
		inModifiers & ePowerMateModifier_Command	? 'C' : '-',
		inModifiers & ePowerMateModifier_Button		? 'B' : '-'];
}

+ (id) createEventWithLocation: (NSUInteger) inDeviceLocation
	type: (NSUInteger) inType
	modifiers: (NSUInteger) inModifiers;
{
	return [[[PMDEvent alloc] initWithLocation: inDeviceLocation
								event: inType modifiers: inModifiers] autorelease];
}

- (id) initWithLocation: (NSUInteger) inDeviceLocation
	event: (NSUInteger) inType
	modifiers: (NSUInteger) inModifiers;
{
    if ((self = [super init]) != NULL) {
		_eventTime = [NSDate timeIntervalSinceReferenceDate];
		_processedOffset = 0.0;
		_eventID = ++sActiveEventID;
		_deviceLocation = inDeviceLocation;
		_type = inType;
		_modifiers = inModifiers;
		_rawValue = 0.0;
		_scaledValue = 0.0;
    }

    return self;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"PMDEvent (%ld) [%ld] %@ %@ - (%f) %f / %f",
			_deviceLocation, _eventID, [PMDEvent stringForType: _type],
			[PMDEvent stringForModifiers: _modifiers], _rps, _scaledValue, _rawValue];
}

@end
