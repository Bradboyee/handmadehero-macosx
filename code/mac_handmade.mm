#include <stdio.h>
#import <AppKit/AppKit.h>
#import <AudioToolbox/AudioToolbox.h>

#define     internal            static
#define     local_persist       static
#define     global_variable     static

#define Assert(Expression) if(Expression) {} else { assert(Expression);}

#define KEY_A 0
#define KEY_S 1
#define KEY_D 2
#define KEY_W 13
#define KEY_ESCAPE 53

typedef     uint8_t         uint8;
typedef     uint16_t        uint16;
typedef     uint32_t        uint32;
typedef     uint32_t	    bool32;

typedef     int8_t          int8;
typedef     int16_t         int16;
typedef     int32_t         int32;

typedef     float           real32;

global_variable     uint32      GlobalWindowWidth       = 960;
global_variable     uint32      GlobalWindowHeight      = 540;
global_variable     bool32      IsRunning               = false;
global_variable     uint32      BufferWidth;
global_variable     uint32      BufferHeight;
global_variable     uint8       *GlobalBuffer;
global_variable     uint32      BytesPerPixel           = 4;
global_variable     uint32      OffsetX                 = 0;
global_variable     uint32      OffsetY                 = 0;
global_variable     uint32      Pitch;
global_variable     uint32      GlobalSampleRate              = 48000;//sample per sec

struct key_state
{
    bool32 IsDown;
};

struct game_controller_input
{
    key_state MoveLeft;
    key_state MoveRight;
    key_state MoveUp;
    key_state MoveDown;

};

internal void MACOSXProcessKey(key_state *Key, bool32 IsDown)
{
    if(Key->IsDown != IsDown)
    {
	Key->IsDown = IsDown;
    }
}

internal void MACOSXProcessKeyCode(NSEvent *Event, game_controller_input *Controller)
{
    bool32 IsDown = (NSEventTypeKeyDown ==  Event.type);
    bool32 IsUp = (NSEventTypeKeyUp == Event.type);
    uint16 KeyCode = Event.keyCode;
    if(IsDown != IsUp)
    {
	if(KeyCode == KEY_ESCAPE)
	{
	    IsRunning = false;
	}
	if(KeyCode == KEY_W)
	{
	    MACOSXProcessKey(&Controller->MoveUp, IsDown);
	}
	if(KeyCode == KEY_A)
	{
	    MACOSXProcessKey(&Controller->MoveLeft, IsDown);
	}
	if(KeyCode == KEY_S)
	{
	    MACOSXProcessKey(&Controller->MoveDown, IsDown);
	}
	if(KeyCode == KEY_D)
	{
	    MACOSXProcessKey(&Controller->MoveRight, IsDown);
	}
    }
}

@interface HandmadeNSWindowDelegate : NSObject<NSWindowDelegate	>;
@end

void CreateBuffer(NSWindow *Window)
{
    BufferWidth = Window.contentView.bounds.size.width;
    BufferHeight = Window.contentView.bounds.size.height;
    Pitch = BufferWidth * BytesPerPixel;
    
    GlobalBuffer = (uint8*) malloc(BufferHeight * Pitch);
}

void RenderGradient(uint32 OffsetX)
{
    uint8 *row = (uint8 *)GlobalBuffer;
    for (uint32 y = 0; y < BufferHeight; y++)
    {
	uint8 *pixel = row;
	for (uint32 x = 0; x < BufferWidth; x++)
	{
	    // R
	    *pixel = 0;
	    ++pixel;
            
	    // G
	    *pixel = (uint8)y + (uint8)OffsetY;
	    ++pixel;
	            
	    // B
	    *pixel = (uint8)x + (uint8)OffsetX;
	    ++pixel;
            
	    // A
	    *pixel = 255;
	    ++pixel;
	}
	row += Pitch;
    }
}

void MacosCreateBitMapData(NSWindow *Window)
{
    @autoreleasepool
    {
	NSBitmapImageRep *BlackBufferImageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes : &GlobalBuffer
						 pixelsWide : BufferWidth
						 pixelsHigh : BufferHeight
						 bitsPerSample : 8
						 samplesPerPixel : BytesPerPixel
						 hasAlpha : YES
						 isPlanar : NO
						 colorSpaceName : NSDeviceRGBColorSpace
						 bytesPerRow : Pitch
						 bitsPerPixel : BytesPerPixel * 8];
        
	NSSize ImageSize = NSMakeSize(BufferWidth, BufferHeight);
	NSImage *Image = [[NSImage alloc] initWithSize : ImageSize];
	[Image addRepresentation : BlackBufferImageRep];
        
	Window.contentView.layer.contents = Image;
		        
	[BlackBufferImageRep release];
	[Image release];
    }
}

@implementation HandmadeNSWindowDelegate
- (void)windowWillClose:(NSNotification *)notification
{
    IsRunning = false;
}
- (void)windowDidResize:(NSNotification *)notification
{
    NSWindow *ResizedWindow = (NSWindow *)notification.object;
    if(GlobalBuffer)
    {
	free(GlobalBuffer);
    }

    CreateBuffer(ResizedWindow);
    RenderGradient(1);
    MacosCreateBitMapData(ResizedWindow);
}
@end

internal OSStatus AudioRenderCallback(void *inRefCon
				      , AudioUnitRenderActionFlags *ioActionFlags
				      , const AudioTimeStamp *inTimeStamp
				      , UInt32 inBusNumber
				      , UInt32 inNumberFrames
				      , AudioBufferList *ioData)
{
    int16 *Channel = (int16 *)ioData->mBuffers[0].mData;

    int SamplesPerSecond = GlobalSampleRate;
    int Frequency = 256;// A4 Note
    int SamplesPerCycle = SamplesPerSecond / Frequency;//sample in one cycle (wavelength)
    int HalfWaveCycle = SamplesPerCycle / 2;
    
    int Amplitude = 3000;
    
    local_persist uint16 RunningIndex = 0;
    for(int i = 0; i < inNumberFrames; i++)
    {
	if((RunningIndex % SamplesPerCycle) > (HalfWaveCycle))
	{
	    *Channel++ = Amplitude;//left
	    *Channel++ = Amplitude;//right
	}
	else
	{
	    *Channel++ = -Amplitude;
	    *Channel++ = -Amplitude;
	}
		
	RunningIndex++;

	if(RunningIndex >= SamplesPerCycle)
	{
	    RunningIndex = 0;
	}
    }
    return noErr;
}

int main(int args,const char *argv[])
{
    //NSRect ScreenRect = [[NSScreen mainscreen] frame];
    printf("start ...");
    NSRect WindowRect = NSMakeRect(50, 50, GlobalWindowWidth, GlobalWindowHeight);
    NSWindow *Window = [[NSWindow alloc] initWithContentRect : WindowRect
			styleMask : NSWindowStyleMaskTitled |
			NSWindowStyleMaskMiniaturizable |
			NSWindowStyleMaskClosable |
			NSWindowStyleMaskResizable
			backing : NSBackingStoreBuffered
			defer : NO];
    
    [Window setBackgroundColor : NSColor.whiteColor];
    [Window setTitle : @"Handmade hero Macosx"];
    [Window makeKeyAndOrderFront : nil];
    
    HandmadeNSWindowDelegate *WindowDelegate = [[HandmadeNSWindowDelegate alloc] init];
    [Window setDelegate : WindowDelegate];
    Window.contentView.wantsLayer = YES;

    CreateBuffer(Window);
    
    AudioComponentDescription AudioDesc = { kAudioUnitType_Output,
	kAudioUnitSubType_DefaultOutput,
	kAudioUnitManufacturer_Apple,
	0,
	0
    };

    int Packet = 1;//collection of frame
    AudioStreamBasicDescription Desc = {0};
    Desc.mFormatID = kAudioFormatLinearPCM;
    Desc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger
	| kLinearPCMFormatFlagIsPacked;
    Desc.mSampleRate = GlobalSampleRate;// normal sample rate.
    Desc.mChannelsPerFrame = 2;
    Desc.mBitsPerChannel = sizeof(uint16) * 8;
    Desc.mBytesPerFrame = sizeof(uint16) * 2;
    Desc.mFramesPerPacket = 1;
    Desc.mBytesPerPacket = Desc.mFramesPerPacket * Desc.mBytesPerFrame;
    Desc.mReserved = 0;
    

    AudioComponentInstance AuUnit;
    AudioComponent AudioComp = AudioComponentFindNext(NULL, &AudioDesc);
    OSStatus err = AudioComponentInstanceNew(AudioComp, &AuUnit);
    err = AudioUnitSetProperty(
	AuUnit,
	kAudioUnitProperty_StreamFormat,
	kAudioUnitScope_Input,
	0,
	&Desc,
	sizeof(Desc));
    
    Assert(err == noErr);

    AURenderCallbackStruct AuCallback;
    AuCallback.inputProc = AudioRenderCallback;
    
    err = AudioUnitSetProperty(
	AuUnit,
	kAudioUnitProperty_SetRenderCallback,
	kAudioUnitScope_Input,
	0,
	&AuCallback,
	sizeof(AuCallback));

    Assert(err == noErr);


    AudioUnitInitialize(AuUnit);
    AudioOutputUnitStart(AuUnit);
    
    game_controller_input Controller = {};
    IsRunning = true;
    while(IsRunning)
    {
	RenderGradient(OffsetX);
	MacosCreateBitMapData(Window);
	
	NSEvent* Event;
	do {
	    Event = [NSApp nextEventMatchingMask: NSEventMaskAny
		     untilDate: nil
		     inMode: NSDefaultRunLoopMode
		     dequeue: YES];
            
	    switch ([Event type])	
	    {
	    case NSEventTypeKeyDown :
	    {
	    } 
	    case NSEventTypeKeyUp :
	    {
		MACOSXProcessKeyCode(Event, &Controller);		
	    } break;
	    default : [NSApp sendEvent: Event];
	    }
	} while (Event != nil);

	if(Controller.MoveLeft.IsDown)
	{
	    OffsetX--;
	}
	if(Controller.MoveRight.IsDown)
	{
	    OffsetX++;
	}
	if(Controller.MoveUp.IsDown)
	{
	    OffsetY--;
	}
	if(Controller.MoveDown.IsDown)
	{
	    OffsetY++;
	}
    }
    
    free(GlobalBuffer);
    printf("finishing ...");
}
