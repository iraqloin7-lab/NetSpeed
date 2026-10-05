#import <UIKit/UIKit.h>
#import <mach/mach.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_var.h>

extern CFMutableDictionaryRef IOServiceMatching(const char *name);
extern mach_port_t IOServiceGetMatchingService(mach_port_t mainPort, CFDictionaryRef matching);
extern kern_return_t IORegistryEntryCreateCFProperties(mach_port_t entry, CFMutableDictionaryRef *properties, CFAllocatorRef allocator, uint32_t options);
extern kern_return_t IOObjectRelease(mach_port_t object);

@interface SBHomeScreenViewController : UIViewController
@end

static UIWindow *win;
static UILabel *lbl;
static UIVisualEffectView *blurView;
static CGFloat scrW = 0;
static uint32_t lastIn = 0, lastOut = 0;

static void readBytes(uint32_t *in, uint32_t *out) {
    struct ifaddrs *ifa, *p;
    *in = 0; *out = 0;
    if (getifaddrs(&ifa) != 0) return;
    for (p = ifa; p; p = p->ifa_next) {
        if (p->ifa_addr && p->ifa_addr->sa_family == AF_LINK && (p->ifa_flags & IFF_UP)) {
            if (!strncmp(p->ifa_name, "en0", 3) || !strncmp(p->ifa_name, "pdp_ip", 6)) {
                struct if_data *d = (struct if_data *)p->ifa_data;
                if (d) { *in += d->ifi_ibytes; *out += d->ifi_obytes; }
            }
        }
    }
    freeifaddrs(ifa);
}

static void readBattery(double *watts, double *temp, BOOL *charging) {
    *watts = 0; *temp = 0; *charging = NO;
    mach_port_t svc = IOServiceGetMatchingService(0, IOServiceMatching("IOPMPowerSource"));
    if (!svc) return;
    CFMutableDictionaryRef props = NULL;
    if (IORegistryEntryCreateCFProperties(svc, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS && props) {
        NSDictionary *d = (__bridge_transfer NSDictionary *)props;
        NSNumber *t = d[@"Temperature"];
        if (t) *temp = t.doubleValue / 100.0;
        NSNumber *a = d[@"InstantAmperage"] ?: d[@"Amperage"];
        NSNumber *v = d[@"Voltage"];
        BOOL ext = [d[@"ExternalConnected"] boolValue];
        if (a && v) {
            int32_t amp = (int32_t)a.longLongValue;
            if (ext && amp > 0) {
                *watts = (amp * v.doubleValue) / 1000000.0;
                *charging = YES;
            }
        }
    }
    IOObjectRelease(svc);
}

static NSString *fmt(uint32_t b) {
    if (b >= 1048576) return [NSString stringWithFormat:@"%.1fM", b / 1048576.0];
    return [NSString stringWithFormat:@"%uK", b / 1024];
}

static void addPart(NSMutableAttributedString *s, NSString *t, UIColor *c, UIFont *f) {
    [s appendAttributedString:[[NSAttributedString alloc] initWithString:t
        attributes:@{NSForegroundColorAttributeName: c, NSFontAttributeName: f}]];
}

static void tick(void) {
    uint32_t i, o;
    readBytes(&i, &o);
    uint32_t di = i - lastIn, dout = o - lastOut;
    lastIn = i; lastOut = o;

    double watts, temp; BOOL chg;
    readBattery(&watts, &temp, &chg);

    UIFont *f = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightSemibold];
    UIColor *green = [UIColor colorWithRed:0.20 green:0.84 blue:0.42 alpha:1];
    UIColor *orange = [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1];
    UIColor *red = [UIColor colorWithRed:1.0 green:0.27 blue:0.23 alpha:1];
    UIColor *yellow = [UIColor colorWithRed:1.0 green:0.84 blue:0.04 alpha:1];
    UIColor *dim = [UIColor colorWithWhite:1 alpha:0.35];
    UIColor *tc = temp >= 40 ? red : (temp >= 35 ? orange : green);

    NSMutableAttributedString *s = [NSMutableAttributedString new];
    addPart(s, @"↓", green, f);
    addPart(s, [NSString stringWithFormat:@" %@  ", fmt(di)], UIColor.whiteColor, f);
    addPart(s, @"↑", orange, f);
    addPart(s, [NSString stringWithFormat:@" %@", fmt(dout)], UIColor.whiteColor, f);
    addPart(s, @"  │  ", dim, f);
    if (chg) {
        NSTextAttachment *at = [NSTextAttachment new];
        UIImage *img = [UIImage systemImageNamed:@"bolt.fill"
            withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:8 weight:UIImageSymbolWeightBold]];
        at.image = [img imageWithTintColor:yellow renderingMode:UIImageRenderingModeAlwaysOriginal];
        at.bounds = CGRectMake(0, -1, 6, 9);
        [s appendAttributedString:[NSAttributedString attributedStringWithAttachment:at]];
        addPart(s, [NSString stringWithFormat:@"%.1fW", watts], yellow, f);
        addPart(s, @"  │  ", dim, f);
    }
    NSString *ts = temp > 0 ? [NSString stringWithFormat:@"%.1f°", temp] : @"--°";
    addPart(s, ts, tc, f);
    lbl.attributedText = s;

    CGSize sz = [lbl sizeThatFits:CGSizeMake(320, 20)];
    CGFloat W = ceil(sz.width) + 22, H = 16;
    win.frame = CGRectMake((scrW - W) / 2, 31, W, H);
    blurView.frame = win.bounds;
    blurView.layer.cornerRadius = H / 2;
    blurView.layer.borderColor = [tc colorWithAlphaComponent:0.55].CGColor;
    lbl.frame = blurView.bounds;

    CGFloat a = ((di + dout) < 1024 && !chg) ? 0.6 : 1.0;
    [UIView animateWithDuration:0.3 animations:^{ win.alpha = a; }];
}

static void setupWindow(UIWindowScene *scene) {
    if (win) return;
    scrW = scene.screen.bounds.size.width;

    win = [[UIWindow alloc] initWithWindowScene:scene];
    win.frame = CGRectMake(0, 31, 100, 16);
    win.windowLevel = 10000;
    win.userInteractionEnabled = NO;
    win.backgroundColor = UIColor.clearColor;

    blurView = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blurView.clipsToBounds = YES;
    blurView.layer.cornerCurve = kCACornerCurveContinuous;
    blurView.layer.borderWidth = 0.8;
    [win addSubview:blurView];

    lbl = [[UILabel alloc] init];
    lbl.textAlignment = NSTextAlignmentCenter;
    [blurView.contentView addSubview:lbl];

    win.hidden = NO;
    readBytes(&lastIn, &lastOut);
    tick();
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){ tick(); }];
}

%hook SBHomeScreenViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIWindowScene *s = self.view.window.windowScene;
    if (s) setupWindow(s);
}
%end
