#import <UIKit/UIKit.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_var.h>

@interface SBHomeScreenViewController : UIViewController
@end

static UIWindow *win;
static UILabel *lbl;
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

    UIFont *f = [UIFont monospacedDigitSystemFontOfSize:9.5 weight:UIFontWeightSemibold];
    UIColor *green = [UIColor colorWithRed:0.20 green:0.84 blue:0.42 alpha:1];
    UIColor *orange = [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1];

    NSMutableAttributedString *s = [NSMutableAttributedString new];
    addPart(s, @"↓", green, f);
    addPart(s, [NSString stringWithFormat:@" %@  ", fmt(di)], UIColor.whiteColor, f);
    addPart(s, @"↑", orange, f);
    addPart(s, [NSString stringWithFormat:@" %@", fmt(dout)], UIColor.whiteColor, f);
    lbl.attributedText = s;

    CGFloat a = (di + dout) < 1024 ? 0.55 : 1.0;
    [UIView animateWithDuration:0.3 animations:^{ win.alpha = a; }];
}

static void setupWindow(UIWindowScene *scene) {
    if (win) return;
    CGFloat w = scene.screen.bounds.size.width;
    CGFloat top = MAX(scene.statusBarManager.statusBarFrame.size.height, 44);
    CGFloat W = 112, H = 20;

    win = [[UIWindow alloc] initWithWindowScene:scene];
    win.frame = CGRectMake(w - W - 12, top + 2, W, H);
    win.windowLevel = 10000;
    win.userInteractionEnabled = NO;
    win.backgroundColor = UIColor.clearColor;

    UIVisualEffectView *blur = [[UIVisualEffectView alloc]
        initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterialDark]];
    blur.frame = win.bounds;
    blur.clipsToBounds = YES;
    blur.layer.cornerRadius = H / 2;
    blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.layer.borderWidth = 0.5;
    blur.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.18].CGColor;
    [win addSubview:blur];

    lbl = [[UILabel alloc] initWithFrame:blur.bounds];
    lbl.textAlignment = NSTextAlignmentCenter;
    [blur.contentView addSubview:lbl];

    win.hidden = NO;
    readBytes(&lastIn, &lastOut);
    [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){ tick(); }];
}

%hook SBHomeScreenViewController
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    UIWindowScene *s = self.view.window.windowScene;
    if (s) setupWindow(s);
}
%end
