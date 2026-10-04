#import <UIKit/UIKit.h>

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application {
    %orig;
    NSLog(@"[NetSpeed] Tweak Loaded Successfully!");
}
%end
