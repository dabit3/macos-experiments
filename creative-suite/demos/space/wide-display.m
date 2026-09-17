#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>

// Native virtual monitor used only for a readable, uncropped demo desktop.
@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)rate;
@end
@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic) unsigned int hiDPI;
@property(nonatomic, retain) NSArray *modes;
@end
@interface CGVirtualDisplayDescriptor : NSObject
@property(nonatomic, retain) NSString *name;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int vendorID;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int serialNum;
@property(nonatomic, retain) dispatch_queue_t queue;
@end
@interface CGVirtualDisplay : NSObject
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@property(nonatomic, readonly) CGDirectDisplayID displayID;
@end

int main(void) {
    @autoreleasepool {
        CGDirectDisplayID original = CGMainDisplayID();
        CGVirtualDisplayDescriptor *descriptor = [CGVirtualDisplayDescriptor new];
        descriptor.name = @"Space Demo Widescreen";
        descriptor.maxPixelsWide = 2400;
        descriptor.maxPixelsHigh = 1350;
        descriptor.sizeInMillimeters = CGSizeMake(600, 338);
        descriptor.vendorID = 0x1234;
        descriptor.productID = 0x9876;
        descriptor.serialNum = 42;
        descriptor.queue = dispatch_get_main_queue();
        CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:descriptor];
        CGVirtualDisplaySettings *settings = [CGVirtualDisplaySettings new];
        settings.hiDPI = 0;
        settings.modes = @[[[CGVirtualDisplayMode alloc] initWithWidth:2400 height:1350 refreshRate:60]];
        if (!display || ![display applySettings:settings]) return 1;
        [NSThread sleepForTimeInterval:1];
        CGDisplayConfigRef config;
        CGBeginDisplayConfiguration(&config);
        CGConfigureDisplayOrigin(config, original, 2400, 0);
        CGConfigureDisplayOrigin(config, display.displayID, 0, 0);
        CGCompleteDisplayConfiguration(config, kCGConfigureForSession);
        printf("Virtual display %u; original %u\n", display.displayID, original);
        fflush(stdout);
        [[NSRunLoop currentRunLoop] run];
    }
}
