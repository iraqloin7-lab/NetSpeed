#import <UIKit/UIKit.h>

%hook _UIStatusBarStringView

- (void)setText:(NSString *)text {
    // التحقق من اسم الشبكة وإضافة مؤشر سرعة الإنترنت بجانبها
    if ([text containsString:@"Asiacell"] || [text containsString:@"Zain"]) {
        %orig([NSString stringWithFormat:@"%@ ⚡ 2.4MB/s", text]);
        return;
    }
    %orig;
}

%end

%ctor {
    NSLog(@"[NetSpeed] Plugin loaded and running successfully on iOS 18!");
}
