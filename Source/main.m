#import <AppKit/AppKit.h>
#import "GSUTMAppDelegate.h"

int main(int argc, const char *argv[])
{
    CREATE_AUTORELEASE_POOL(pool);
    [NSApplication sharedApplication];
    [NSApp setDelegate:[[GSUTMAppDelegate alloc] init]];
    RELEASE(pool);
    return NSApplicationMain(argc, argv);
}
