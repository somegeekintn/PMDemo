//
//  PMDManager.m
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//

#import "PMDManager.h"
#import "PMDDevice.h"
#import "PMDEvent.h"

#include <IOKit/IOKitLib.h>
#include <IOKit/hid/IOHIDKeys.h>

static PMDManager		*sSharedManager = nil;

@interface PMDManager (Private)

- (void)		matchDevices;

@end

static void DeviceAdded(
	void			*inRefCon,
	io_iterator_t   inIterator)
{
	PMDManager		*manager = (PMDManager *)inRefCon;
	PMDDevice		*device;
	mach_timespec_t	waitTime;
	io_service_t	obj;
	kern_return_t	result;
	
	waitTime.tv_sec = 5;
	waitTime.tv_nsec = 0;
	
	while ((obj = IOIteratorNext(inIterator))) {
		result = IOServiceWaitQuiet(obj, &waitTime);		// fix for radar://5474691
		if (result != kIOReturnSuccess || (device = [[PMDDevice alloc] initWithService: obj]) == nil) {
			// TODO: this does seem to happen on occasion even after the IOKit dictionary is stable 
			NSLog(@"Failed to create object for devce");
			IOObjectRelease(obj);
		}
		else {
			[manager addDevice: device];
			[device release];
		}
	}
}

static void DeviceRemoved(
	void			*inRefCon,
	io_iterator_t   inIterator)
{
	PMDManager		*manager = (PMDManager *) inRefCon;
	PMDDevice		*device;
	io_service_t	obj;
	
	while ((obj = IOIteratorNext(inIterator))) {
		if ((device = [manager deviceWithService: obj]) != nil)
			[manager removeDevice: device];
	}
}


@implementation PMDManager

@synthesize lastEvent = _lastEvent;
@synthesize eventActive = _eventActive;

+ (PMDManager *) sharedManager
{
	@synchronized(self) {
		if (sSharedManager == nil)
			[[self alloc] init];
	}
	
	return sSharedManager;
}

+ (id) allocWithZone: (NSZone *) inZone
{
	PMDManager	*manager = sSharedManager;

	@synchronized(self) {
		if (manager == nil)
			manager = sSharedManager = [super allocWithZone: inZone];
	}

	return manager;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"PowerMate Manager %ld devices", [_devices count]];
}

- (id) init
{
	if ((self = [super init]) != nil) {
		_lock = [[NSRecursiveLock alloc] init];
		_devices = [[NSMutableArray array] retain];
		_lastEvent = nil;
	}

	return self;
}

- (id) copyWithZone: (NSZone *) inZone
{
    return self;
}
 
- (id) retain
{
    return self;
}
 
- (NSUInteger) retainCount
{
    return NSUIntegerMax;
}
 
- (oneway void) release
{
}
 
- (id) autorelease
{
    return self;
}

- (void) start
{
	[NSThread detachNewThreadSelector: @selector(startPowerMateRunLoop:) toTarget: self withObject: self];
}

- (void) startPowerMateRunLoop: (id) inObj
{
	NSAutoreleasePool	*ourPool = [[NSAutoreleasePool alloc] init];
	BOOL				running = YES;
	
	_pwrmateLoop = [NSRunLoop currentRunLoop];
	[self matchDevices];
	[ourPool release];
	
	while (running) {
		ourPool = [[NSAutoreleasePool alloc] init];
		
		// we stop every now and again to clear the autorelease pool
		running = [_pwrmateLoop runMode: NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow: 2]];
		
		[ourPool release];
	}
}

- (void) matchDevices
{
	CFMutableDictionaryRef  matchingDict;
	CFRunLoopSourceRef 		runLoopSource;
	IOReturn				result;
	
	matchingDict = IOServiceMatching(kIOHIDDeviceKey);
	NSAssert(matchingDict != nil, @"IOServiceMatching kIOHIDDeviceKey failed");
	
	CFRetain(matchingDict);		// IOServiceAddMatchingNotification will consume a reference and it will be called twice, hence the extra retain
	CFDictionarySetValue(matchingDict, [NSString stringWithCString: kIOHIDProductIDKey encoding: NSUTF8StringEncoding], [NSNumber numberWithLong: kPowerMateProductID]);
	CFDictionarySetValue(matchingDict, [NSString stringWithCString: kIOHIDVendorIDKey encoding: NSUTF8StringEncoding], [NSNumber numberWithLong: kPowerMateVendorID]);
	_notifyPort = IONotificationPortCreate(kIOMasterPortDefault);
	
	result = IOServiceAddMatchingNotification(_notifyPort, kIOFirstMatchNotification, matchingDict, &DeviceAdded, self, &_deviceIterator);
	NSAssert1(result == kIOReturnSuccess, @"IOServiceAddMatchingNotification kIOFirstMatchNotification failed: %08x", result);
	DeviceAdded((void *)self, _deviceIterator);			// check matching devices suplied by iterator
	
	result = IOServiceAddMatchingNotification(_notifyPort, kIOTerminatedNotification, matchingDict, &DeviceRemoved, self, &_deviceIterator);
	NSAssert1(result == kIOReturnSuccess, @"IOServiceAddMatchingNotification kIOTerminatedNotification failed: %08x", result);
	DeviceRemoved((void *)self, _deviceIterator);		// check matching devices suplied by iterator
				
	runLoopSource = IONotificationPortGetRunLoopSource(_notifyPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
}

- (NSRunLoop *) runLoop
{
	return _pwrmateLoop;
}

- (NSArray *) devices
{
	return _devices;
}

- (NSUInteger) countOfDevices
{
	return [_devices count];
}

- (PMDDevice *) objectInDevicesAtIndex: (NSUInteger) inIndex
{
	return inIndex < [_devices count] ? [_devices objectAtIndex: inIndex] : nil;
}

- (void) insertObject: (PMDDevice *) inDevice
	inDevicesAtIndex: (NSUInteger) inIndex
{	
	[_lock lock];

		[_devices insertObject: inDevice atIndex: inIndex];
		
	[_lock unlock];
}

- (void) removeObjectFromDevicesAtIndex: (NSUInteger) inIndex
{
	[_lock lock];

		[_devices removeObjectAtIndex: inIndex];
		
	[_lock unlock];
}

- (PMDDevice *) deviceWithService: (io_service_t) inServiceID
{
	return [self deviceWithLocation: [PMDDevice locationOfServiceID: inServiceID]];
}

- (PMDDevice *) deviceWithLocation: (UInt32) inLocation
{
	PMDDevice	*theDevice = nil;
	
	[_lock lock];

		if (inLocation == 0)		// location 0 designants any device
			theDevice = [self objectInDevicesAtIndex: 0];
		else {
			for (PMDDevice *device in _devices) {
				if ([device locationID] == inLocation) {
					theDevice = device;
					break;
				}
			}
		}
		
	[_lock unlock];
	
	return theDevice;
}


- (void) addDevice: (PMDDevice *) inDevice
{
	[_lock lock];
		
		[self insertObject: inDevice inDevicesAtIndex: [self countOfDevices]];
		
	[_lock unlock];
}

- (void) removeDevice: (PMDDevice *) inDevice
{
	NSUInteger		deviceIndex;
	
	[_lock lock];

		deviceIndex = [_devices indexOfObject: inDevice];
		if (deviceIndex != NSNotFound) {
			[inDevice shutdown];
			[self removeObjectFromDevicesAtIndex: deviceIndex];
		}
		
	[_lock unlock];
}


- (void) handleEvent: (PMDEvent *) inEvent
{
	self.eventActive = YES;
	
	self.lastEvent = [inEvent description];

	self.eventActive = NO;
}

@end
 
