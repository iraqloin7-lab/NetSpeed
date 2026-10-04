#import <UIKit/UIKit.h>

%hook _UIStatusBarStringView
- (void)setText:(NSString *)text {
    // يمكنك تعديل هذه الرسالة أو دمجها مع دالة حساب سرعة الشبكة
    if ([text containsString:@"K"] || [text containsString:@"M"] || [text isEqualToString:@""]) {
        %orig;
        return;
    }
    
    // مثال: إضافة علامة بجانب الشبكة أو تغيير النص للتأكد من عمل الأداة
    %orig;
}
%end

// دالة تهيئة الأداة عند تشغيل النظام
%ctor {
    @autoreleasepool {
        NSLog(@"[NetSpeed] Tweak loaded successfully on iOS 18 RootHide!");
    }
}
