//
//  PMDEvent.h
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//

#import <Cocoa/Cocoa.h>

enum {
    ePowerMateAction_ButtonPress = 0,
    ePowerMateAction_ButtonRelease,
    ePowerMateAction_RotateLeft,
    ePowerMateAction_RotateRight,
    ePowerMateAction_ButtonLongPress,
    ePowerMateAction_NumActions
};

enum {
    ePowerMateModifier_None = 0x00,
    ePowerMateModifier_Shift = 0x01,
    ePowerMateModifier_Control = 0x02,
    ePowerMateModifier_Option = 0x04,
    ePowerMateModifier_Command = 0x08,
    ePowerMateModifier_Button = 0x10
};

@interface PMDEvent : NSObject
{
	NSTimeInterval	_eventTime;
	NSTimeInterval	_processedOffset;
	UInt64			_eventID;
	NSUInteger		_deviceLocation;
	NSUInteger		_type;
	NSUInteger		_previousType;
	NSUInteger		_modifiers;
	
	double			_rawValue;
	double			_scaledValue;
	double			_rps;
	BOOL			_validRPS;
}

+ (NSString *)		stringForType: (NSUInteger) inType;
+ (NSString *)		stringForModifiers: (NSUInteger) inModifiers;

+ (id)				createEventWithLocation: (NSUInteger) inDeviceLocation
						type: (NSUInteger) inType
						modifiers: (NSUInteger) inModifiers;
- (id)				initWithLocation:  (NSUInteger) inDeviceLocation
						event: (NSUInteger) inType
						modifiers: (NSUInteger) inModifiers;
						
@property (assign) double			rawValue, scaledValue, rps;
@property (assign) BOOL				validRPS;
@property (assign) NSTimeInterval	processedOffset;
@property (assign) NSUInteger		previousType;
@property (readonly) UInt64			eventID;
@property (readonly) NSUInteger		deviceLocation, type, modifiers;
@property (readonly) NSTimeInterval	eventTime;

@end
