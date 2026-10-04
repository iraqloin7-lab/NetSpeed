#import <UIKit/UIKit.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <net/if_var.h>

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

static void tick(void) {
    uint32_t i, o;
    readBytes(&i, &o);
    uint32_t di = i - lastIn, dout = o - lastOut;
    lastIn = i; lastOut = o;
    lbl.text = [NSString stringWithFormat:@"↓%@ ↑%@", fmt(di), fmt(dout)];
}

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)app {
    %orig;
    dispatch_async(dispatch_get_main_queue(), ^{
        CGFloat w = UIScreen.mainScreen.bounds.size.width;
        win = [[UIWindow alloc] initWithFrame:CGRectMake(w - 110, 24, 105, 14)];
        win.windowLevel = 10000;
        win.userInteractionEnabled = NO;
        win.backgroundColor = UIColor.clearColor;
        lbl = [[UILabel alloc] initWithFrame:win.bounds];
        lbl.font = [UIFont monospacedDigitSystemFontOfSize:9 weight:UIFontWeightSemibold];
        lbl.textColor = UIColor.whiteColor;
        lbl.textAlignment = NSTextAlignmentRight;
        [win addSubview:lbl];
        win.hidden = NO;
        readBytes(&lastIn, &lastOut);
        [NSTimer scheduledTimerWithTimeInterval:1 repeats:YES block:^(NSTimer *t){ tick(); }];
    });
}
%end
