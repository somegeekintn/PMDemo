//
//  PMDDevice.h
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//

#import <Cocoa/Cocoa.h>
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/hid/IOHIDLib.h>

#define kPowerMateReportBufferSize		6
#define kRotationAvgSize				32

@interface PMDDevice : NSObject
{
	io_service_t				_serviceID;
	UInt32						_locationID;
	IOUSBDeviceInterface		**_usbDevice;
	IOHIDDeviceInterface122		**_hidDevice;
	
	UInt8						_buffer[kPowerMateReportBufferSize];
	
	NSString					*_name;
	CGFloat						_brightness;
	CGFloat						_pulseRate;
	BOOL						_shouldPulse;
	BOOL						_initComplete;
	
	NSTimeInterval				_lastButtonTime;
	NSTimeInterval				_lastRotateTime;
	UInt64						_activeEventID;
	double						_rotationSpeed[kRotationAvgSize];
	NSUInteger					_rotationIndex;
	NSUInteger					_lastAction;
	UInt8						_lastButton;
	BOOL						_rotationFull;
}

+ (UInt32)			locationOfServiceID: (io_service_t) inServiceID;

- (id)				initWithService: (io_service_t) inServiceID;
- (void)			shutdown;

- (io_service_t)	serviceID;
- (UInt32)			locationID;
- (NSString *)		locationName;

@property (nonatomic, copy) NSString		*name;
@property (nonatomic, assign) UInt64		activeEventID;
@property (nonatomic, assign) CGFloat		brightness, pulseRate;
@property (nonatomic, assign) BOOL			shouldPulse;

@end
