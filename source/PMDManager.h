//
//  PMDManager.h
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//

#import <Cocoa/Cocoa.h>

#define kPowerMateVendorID		0x077d
#define kPowerMateProductID		0x0410

@class PMDDevice;
@class PMDEvent;

@interface PMDManager : NSObject
{
	NSRecursiveLock			*_lock;
	NSMutableArray			*_devices;
	
	NSRunLoop				*_pwrmateLoop;
	IONotificationPortRef 	_notifyPort;
	io_iterator_t			_deviceIterator;
	
	NSString				*_lastEvent;
	BOOL					_eventActive;
}

+ (PMDManager *)	sharedManager;

- (void)			start;
- (NSRunLoop *)		runLoop;

- (NSArray *)		devices;
- (NSUInteger)		countOfDevices;
- (PMDDevice *)		objectInDevicesAtIndex: (NSUInteger) inIndex;
- (void)			insertObject: (PMDDevice *) inDevice
						inDevicesAtIndex: (NSUInteger) inIndex;
- (void)			removeObjectFromDevicesAtIndex: (NSUInteger) inIndex;
- (PMDDevice *)		deviceWithService: (io_service_t) inServiceID;
- (PMDDevice *)		deviceWithLocation: (UInt32) inLocation;
- (void)			addDevice: (PMDDevice *) inDevice;
- (void)			removeDevice: (PMDDevice *) inDevice;

- (void)			handleEvent: (PMDEvent *) inEvent;

@property (assign) BOOL			eventActive;
@property (copy) NSString		*lastEvent;

@end
