"""A real native AppKit source viewer for the running GUI test."""
import json
import os
import sys
import textwrap
from pathlib import Path
import AppKit as A
import objc
from Foundation import NSObject, NSTimer

STATE = Path(sys.argv[1])
COMPACT = os.environ.get("SPACE_COMPACT") == "1"


def color(hex):
    return A.NSColor.colorWithCalibratedRed_green_blue_alpha_(
        int(hex[0:2],16)/255,int(hex[2:4],16)/255,int(hex[4:6],16)/255,1)


class Panel(A.NSView):
    def isFlipped(self):
        return True

    @objc.python_method
    def text(self, string, x, y, size=17, ink="E8EEE9", mono=False):
        font = (A.NSFont.monospacedSystemFontOfSize_weight_(size, A.NSFontWeightRegular)
                if mono else A.NSFont.systemFontOfSize_weight_(size,A.NSFontWeightMedium))
        A.NSString.stringWithString_(str(string)).drawAtPoint_withAttributes_(
            (x,y),{A.NSFontAttributeName:font,A.NSForegroundColorAttributeName:color(ink)})

    def drawRect_(self, rect):
        color("101A20").setFill()
        A.NSRectFill(self.bounds())
        try:
            s=json.loads(STATE.read_text())
        except (OSError,ValueError):
            s={"chapter":"Ready for native UI test", "status":"READY"}
        if COMPACT:
            self.compact(s)
            return
        self.text("SPACE  /  NATIVE UI TEST",32,30,14,"83BDAF",True)
        self.text("ORBIT",30,63,56)
        self.text("A study in copper & porcelain",32,132,21,"B5C7C5")
        color("2A4047").setFill()
        A.NSRectFill(((32,183),(668,1)))
        self.text(s.get("chapter",""),32,212,25)
        self.text(s.get("subtitle","Actual app • actual actions • actual source"),32,255,16,"9FB4B7")
        self.text("EXECUTING  ·  "+s.get("file","scenario.py"),32,310,13,"83BDAF",True)
        lines=s.get("lines",[])
        active=s.get("line",0)
        for i, item in enumerate(lines):
            number, line=item
            y=350+i*25
            if number==active:
                color("213E46").setFill()
                A.NSRectFill(((20,y-3),(695,25)))
                self.text("›",23,y,17,"BAE9CA",True)
            self.text(f"{number:03}",42,y,15,"647F89",True)
            ink="BAE9CA" if number==active else "D3E0E2"
            if line.lstrip().startswith("#"):
                ink="83A2AA"
            self.text(line,88,y,15,ink,True)
        self.text("LIVE ASSERTIONS",32,858,13,"83BDAF",True)
        results=s.get("results",[])
        for i,r in enumerate(results[-9:]):
            ink="FF9D85" if r["status"]=="FAIL" else "BAE9CA"
            self.text(r["status"],32,895+i*32,14,ink,True)
            self.text(r["text"][:61],94,894+i*32,16)
        passed=sum(r["status"]=="PASS" for r in results)
        failed=sum(r["status"]=="FAIL" for r in results)
        color("2A4047").setFill()
        A.NSRectFill(((32,1202),(668,1)))
        self.text(f'{s.get("status","READY")}   /   {passed} checks   /   {failed} failures',
                  32,1224,17,"BAE9CA",True)
        self.text("Quartz pointer + keyboard · native Accessibility",32,1265,14,"819BA3")
        self.text("No document injection. Visuals reviewed separately.",32,1289,14,"819BA3")

    @objc.python_method
    def compact(self, s):
        self.text("SPACE / BUILT-IN COMPUTER TEST",18,20,12,"83BDAF",True)
        self.text("ORBIT",18,48,38)
        self.text(s.get("chapter","Ready"),18,105,21)
        for i,line in enumerate(textwrap.wrap(s.get("subtitle",""),55)):
            self.text(line,18,140+i*18,13,"9FB4B7")
        self.text("EXECUTING · "+s.get("file","scenario.py"),18,194,12,"83BDAF",True)
        y=225
        for number,line in s.get("lines",[]):
            active=number==s.get("line")
            for j,part in enumerate(textwrap.wrap(line,54,replace_whitespace=False,
                                                  drop_whitespace=False) or [""]):
                if active:
                    color("213E46").setFill()
                    A.NSRectFill(((10,y-2),(460,18)))
                self.text(f"{number:03}" if j==0 else "   ",18,y,12,"647F89",True)
                self.text(part,53,y,12,"BAE9CA" if active else "D3E0E2",True)
                y+=18
        y=max(y+20,770)
        self.text("LIVE ASSERTIONS",18,y,12,"83BDAF",True)
        results=s.get("results",[])
        for r in results[-7:]:
            y+=25
            self.text(r["status"],18,y,12,
                      "FF9D85" if r["status"]=="FAIL" else "BAE9CA",True)
            self.text(r["text"][:57],63,y,12)
        passed=sum(r["status"]=="PASS" for r in results)
        failed=sum(r["status"]=="FAIL" for r in results)
        self.text(f'{s.get("status","READY")} / {passed} checks / {failed} failures',
                  18,1090,15,"BAE9CA",True)
        self.text("Computer actions + disclosed native input fallback",18,1130,12,"819BA3")
        self.text("No document injection · visual checks separate",18,1150,12,"819BA3")


class Refresh(NSObject):
    def tick_(self, timer):
        panel.setNeedsDisplay_(True)


app=A.NSApplication.sharedApplication()
app.setActivationPolicy_(A.NSApplicationActivationPolicyAccessory)
window=A.NSWindow.alloc().initWithContentRect_styleMask_backing_defer_(
    ((1120,0),(480,1170)) if COMPACT else ((1665,0),(735,1320)),
    A.NSWindowStyleMaskBorderless,A.NSBackingStoreBuffered,False)
window.setLevel_(A.NSFloatingWindowLevel)
window.setTitle_("Space • Executing test source")
panel=Panel.alloc().initWithFrame_(((0,0),(480,1170) if COMPACT else (735,1320)))
window.setContentView_(panel)
window.orderFrontRegardless()
refresh=Refresh.new()
timer=NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
    .08,refresh,"tick:",None,True)
app.run()
