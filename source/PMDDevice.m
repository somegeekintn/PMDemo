//
//  PMDDevice.m
//  PMDemo
//
//  Created by Casey Fleser on 6/2/10.
//

#import "PMDDevice.h"
#import "PMDManager.h"
#import "PMDEvent.h"

#import <IOKit/IOKitLib.h>
#import <IOKit/IOCFPlugIn.h>
#include <tgmath.h>

#define kPowerMateCmd_SetBrightness		0x0001
#define kPowerMateCmd_SetSleepPulse		0x0002
#define kPowerMateCmd_SetAlwaysPulse	0x0003
#define kPowerMateCmd_SetPulseRate		0x0004
#define kPowerMateRevolutionUnits		96.0

@interface PMDDevice (Private)

- (void)		initHIDInterface;
- (void)		initDeviceInterface;
- (IOReturn)	openAndSetInterrupt;

- (CGFloat)		setTimeSinceLast: (NSTimeInterval) inTimeSinceLast
					rotationAmount: (double) inRotationAmount
					hasValidRPS: (BOOL *) outValidRPS;
- (void)		processReadData;

@end

void PowerMateCallbackFunction(
	void *	 		inTarget,
	IOReturn 		inResult,
	void * 			inRefcon,
	void * 			inSender,
	uint32_t		inBufferSize)
{
	if (inResult == kIOReturnSuccess) {
		PMDDevice		*device = (PMDDevice *)inTarget;

		UpdateSystemActivity(UsrActivity);		// wakie wake
		
		[device processReadData];
	}
}

@implementation PMDDevice

@synthesize name = _name;
@synthesize pulseRate = _pulseRate;
@synthesize shouldPulse = _shouldPulse;
@synthesize brightness = _brightness;
@synthesize activeEventID = _activeEventID;

+ (UInt32) locationOfServiceID: (io_service_t) inServiceID
{
	CFMutableDictionaryRef	properties;
	CFNumberRef				location;
	IOReturn				result;
	UInt32					locationValue = 0;
	
	result = IORegistryEntryCreateCFProperties(inServiceID, &properties, kCFAllocatorDefault, kNilOptions);
	NSAssert1(result == kIOReturnSuccess, @"Failed to retrieve device properties: %08x", result);
	
	location = CFDictionaryGetValue(properties, CFSTR(kIOHIDLocationIDKey));
	NSAssert(location != NULL, @"Unable to determine device location");
	
	CFNumberGetValue(location, kCFNumberIntType, &locationValue);

	CFRelease(properties);
	
	return locationValue;
}

- (NSString *) description
{
	return [NSString stringWithFormat: @"PowerMate Device location: %08x service: %08x", _locationID, _serviceID];
}

- (id) initWithService: (io_service_t) inServiceID
{
	if ((self = [super init]) != nil) {
		_serviceID = inServiceID;
		_locationID = [PMDDevice locationOfServiceID: _serviceID];

		[self initHIDInterface];
		[self initDeviceInterface];

		if (_usbDevice != NULL && _hidDevice != NULL) {
			if ([self openAndSetInterrupt] == kIOReturnSuccess) {
				self.name = [NSString stringWithFormat: @"PowerMate %ld", [[PMDManager sharedManager] countOfDevices] + 1];

				_initComplete = YES;
			}
		}
		
		if (!_initComplete) {
			if (_usbDevice != NULL) {
				(*_usbDevice)->Release(_usbDevice);
				_usbDevice = NULL;
			}
			if (_hidDevice != NULL) {
				(*_hidDevice)->Release(_hidDevice);
				_hidDevice = NULL;
			}
			
			IOObjectRelease(_serviceID);
			self = nil;
		}
	}
	
	return self;
}

- (void) initHIDInterface
{
    IOCFPlugInInterface		**iodev = NULL;
	IOReturn				result;
    SInt32					score;
	
	result = IOCreatePlugInInterfaceForService(_serviceID, kIOHIDDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
	
	if (result == kIOReturnSuccess) {
		IOHIDDeviceInterface122		**hidDeviceInterface;

		if ((*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOHIDDeviceInterfaceID122), (LPVOID) &hidDeviceInterface) == kIOReturnSuccess)
			_hidDevice = hidDeviceInterface;

		if (iodev != NULL)
			(*iodev)->Release(iodev);
	}
}

- (void) initDeviceInterface
{
	CFMutableDictionaryRef  matchingDict;
	IOCFPlugInInterface		**iodev = NULL;
	io_iterator_t			deviceIterator;
	io_object_t				usbDevice;
	IOReturn				result;
	SInt32					score;
	
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	NSAssert(matchingDict != NULL, @"IOServiceMatching kIOHIDDeviceKey failed");

	CFDictionarySetValue(matchingDict, CFSTR(kUSBProductID), [NSNumber numberWithShort: kPowerMateProductID]);
	CFDictionarySetValue(matchingDict, CFSTR(kUSBVendorID), [NSNumber numberWithShort: kPowerMateVendorID]);

	result = IOServiceGetMatchingServices(kIOMasterPortDefault, matchingDict, &deviceIterator);
	NSAssert1(result == kIOReturnSuccess, @"IOServiceGetMatchingServices failed: %08x", result);
	
	while (IOIteratorIsValid(deviceIterator) && (usbDevice = IOIteratorNext(deviceIterator)) && _usbDevice == NULL) {
		result = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &iodev, &score);
		if (result == kIOReturnSuccess) {
			IOUSBDeviceInterface		**usbDeviceInterface;

			result = (*iodev)->QueryInterface(iodev, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID), (LPVOID) &usbDeviceInterface);
			if (result == kIOReturnSuccess) {
				UInt32			deviceLocationID;
				
				result = (*usbDeviceInterface)->GetLocationID(usbDeviceInterface, &deviceLocationID);
				if (result == kIOReturnSuccess) {
					if (deviceLocationID == _locationID) {
						_usbDevice = usbDeviceInterface;
					}
				}
			}
			
			if (_usbDevice == NULL)
				IOObjectRelease(usbDevice);

			if (iodev != NULL) {
				(*iodev)->Release(iodev);
				iodev = NULL;
			}
		}
	}

	IOObjectRelease(deviceIterator);
}

- (IOReturn) openAndSetInterrupt
{
	IOReturn				result;
 	
	if ((result = (*_hidDevice)->open(_hidDevice, 0)) == kIOReturnSuccess) {
		CFRunLoopSourceRef		eventSource;
		
		result = (*_hidDevice)->createAsyncEventSource(_hidDevice, &eventSource);
		NSAssert1(result == kIOReturnSuccess, @"Could not create event source for device: %08x", result);
		
		CFRunLoopAddSource([[[PMDManager sharedManager] runLoop] getCFRunLoop], eventSource, kCFRunLoopDefaultMode);
		
		result = (*_hidDevice)->setInterruptReportHandlerCallback(_hidDevice, _buffer, kPowerMateReportBufferSize, PowerMateCallbackFunction, self, nil);
		NSAssert1(result == kIOReturnSuccess, @"Failed to create interrupt handler for device: %08x", result);
	}
		
	return result;
}

- (void) dealloc
{
	[self shutdown];
	
	IOObjectRelease(_serviceID);
	
	[_name release];
	
	[super dealloc];
}

- (void) shutdown
{
	if (_hidDevice != NULL) {
		(*_hidDevice)->close(_hidDevice);
		(*_hidDevice)->Release(_hidDevice);
		_hidDevice = NULL;
	}
	if (_usbDevice != NULL) {
		(*_usbDevice)->Release(_usbDevice);
		_usbDevice = NULL;
	}
}

- (NSScriptObjectSpecifier *) objectSpecifier
{
	NSScriptClassDescription	*containerDescription = [NSScriptClassDescription classDescriptionForClass: [NSApp class]];
	
	return [[[NSUniqueIDSpecifier alloc] initWithContainerClassDescription: containerDescription containerSpecifier: nil key: @"devices" uniqueID: [self locationName]] autorelease];
}

- (void) sendCommand: (UInt16) inCommand
	withValue: (UInt16) inValue
{
	IOReturn			result;

	if ((result = (*_usbDevice)->USBDeviceOpen(_usbDevice)) == kIOReturnSuccess) {
		IOUSBDevRequest		request;
		
		request.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBInterface);
		request.bRequest = 1;
		request.wValue = inCommand;
		request.wIndex = inValue;
		request.wLength = 0x0000;
		request.pData = nil;
		
		result = (*_usbDevice)->DeviceRequest(_usbDevice, &request);
		if (result != kIOReturnSuccess)
			NSLog(@"%@ DeviceRequest failed: %08x", self, result);
		
		(*_usbDevice)->USBDeviceClose(_usbDevice);
	}
	else {
		NSLog(@"%@ USBDeviceOpen failed: %08x", self, result);
	}
}

- (io_service_t) serviceID
{
	return _serviceID;
}

- (UInt32) locationID
{
	return _locationID;
}

- (NSString *) locationName
{
	return [NSString stringWithFormat: @"%08x", _locationID];
}

- (void) setName: (NSString *) inName
{
    if (_name != inName) {
		[_name release];
		_name = [inName copy];
	}
}

- (void) updateBrightness
{
	[self sendCommand: kPowerMateCmd_SetBrightness withValue: _brightness * 255];
}

- (void) setBrightness: (CGFloat) inBrightness
{
	if (inBrightness < 0.0)
		inBrightness = 0.0;
	else if (inBrightness > 1.0)
		inBrightness = 1.0;

    if (!_initComplete || _brightness != inBrightness) {
		_brightness = inBrightness;
		
		[self updateBrightness];
	}
}

- (void) updatePulseRate
{
	UInt16		baseValue;
	
	baseValue = (UInt16)(_pulseRate * 64);
	
	// values range from:
	// 0x0f00 - 0x0000 / 0x0002 - 0x2f02
	[self sendCommand: kPowerMateCmd_SetPulseRate withValue: (baseValue < 16) ? ((15 - baseValue) << 8) : ((baseValue - 16) << 8) + 0x0002];
}

- (void) setPulseRate: (CGFloat) inPulseRate
{
	if (inPulseRate < 0.0)
		inPulseRate = 0.0;
	else if (inPulseRate > 1.0)
		inPulseRate = 1.0;
		
	if (!_initComplete || _pulseRate != inPulseRate) {
		_pulseRate = inPulseRate;
		
		[self updatePulseRate];
	}
}

- (void) setShouldPulse: (BOOL) inShouldPulse
{
    if (!_initComplete || _shouldPulse != inShouldPulse) {
		_shouldPulse = inShouldPulse;
		
		[self sendCommand: kPowerMateCmd_SetAlwaysPulse withValue: _shouldPulse];
		if (_shouldPulse)
			[self updatePulseRate];
		else
			[self updateBrightness];
	}
}

- (CGFloat) setTimeSinceLast: (NSTimeInterval) inTimeSinceLast
	rotationAmount: (double) inRotationAmount
	hasValidRPS: (BOOL *) outValidRPS
{
	double		average;
	NSInteger			i;

	if (inRotationAmount < 0.0)
		inRotationAmount = -inRotationAmount;

	if (inTimeSinceLast > 0.2) {	// reset
		_rotationFull = NO;
		_rotationIndex = 0;
		average = 0.3;				// default 0.3 revolutions per second
		
		for (i=0; i<kRotationAvgSize; i++)
			_rotationSpeed[i] = average;
			
		if (outValidRPS != NULL)
			*outValidRPS = NO;
	}
	else {
		NSInteger		validCnt;
		double			rps = inRotationAmount / inTimeSinceLast;
		
		_rotationSpeed[_rotationIndex] = rps;
		_rotationIndex++;
		if (_rotationIndex >= kRotationAvgSize) {
			_rotationIndex = 0;
			_rotationFull = YES;
		}
		
		validCnt = _rotationFull ? kRotationAvgSize : (_rotationIndex + 1);
		average = 0.0;
		for (i=0; i<validCnt; i++)
			average += _rotationSpeed[i];
		
		average /= validCnt;
		
		if (outValidRPS != NULL)
			*outValidRPS = YES;
	}

	return average;		// revolutions per second
}

- (void) processReadData
{
	// If the manager is busy, toss this event to avoid a stack overflow 
	if (![[PMDManager sharedManager] eventActive]) {
		NSTimeInterval	eventTime = [NSDate timeIntervalSinceReferenceDate];
		SInt8			newButton = _buffer[0];
		SInt8			newRotate = _buffer[1];
		NSUInteger		modifiers = [NSEvent modifierFlags];
		NSUInteger		eventType;
		NSUInteger		eventModifiers = 0;
		PMDEvent		*devEvent;
		
		if (modifiers & NSCommandKeyMask)
			eventModifiers |= ePowerMateModifier_Command;
		if (modifiers & NSShiftKeyMask)
			eventModifiers |= ePowerMateModifier_Shift;
		if (modifiers & NSAlternateKeyMask)
			eventModifiers |= ePowerMateModifier_Option;
		if (modifiers & NSControlKeyMask)
			eventModifiers |= ePowerMateModifier_Control;

		if (_lastButton != newButton) {
			eventType = newButton ? ePowerMateAction_ButtonPress : ePowerMateAction_ButtonRelease;
			devEvent = [PMDEvent createEventWithLocation: [self locationID] type: eventType modifiers: eventModifiers];
			
			_activeEventID = devEvent.eventID;
			[[PMDManager sharedManager] handleEvent: devEvent]; 
			_lastAction = devEvent.type;
			_lastButton = newButton;
			_lastButtonTime = eventTime;
		}
		
		if (newRotate && eventTime - _lastButtonTime > 0.25) {	// no turny if pressed within last 1/4 second
			double		rps, multiplier, rawDelta, scaledDelta;
			BOOL		validRPS;
			
			rawDelta = (double)newRotate / kPowerMateRevolutionUnits;
			rps = [self setTimeSinceLast: eventTime - _lastRotateTime rotationAmount: rawDelta hasValidRPS: &validRPS];
			multiplier = pow(2, rps) - 1.0;
			scaledDelta = rawDelta * multiplier;

			if (newButton)
				eventModifiers |= ePowerMateModifier_Button;

			eventType = rawDelta < 0.0 ? ePowerMateAction_RotateLeft : ePowerMateAction_RotateRight;
			devEvent = [PMDEvent createEventWithLocation: [self locationID] type: eventType modifiers: eventModifiers];
			devEvent.rawValue = rawDelta;
			devEvent.scaledValue = scaledDelta;
			devEvent.rps = rps;
			devEvent.validRPS = validRPS;
			devEvent.previousType = _lastAction;

			_activeEventID = [devEvent eventID];
			[[PMDManager sharedManager] handleEvent: devEvent];
			
			_lastAction = eventType;
			_lastRotateTime = eventTime;
		}
	}
}

@end
