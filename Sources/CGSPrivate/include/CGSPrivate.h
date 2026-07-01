#ifndef CGS_PRIVATE_H
#define CGS_PRIVATE_H

#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>

// 非公開 CoreGraphicsServices(SkyLight)API の宣言。
// Hammerspoon / AeroSpace / yabai と同じ手法で、実体は
// /System/Library/Frameworks/ApplicationServices.framework 経由でリンクされる。

typedef int CGSConnectionID;
typedef size_t CGSSpaceID;

typedef enum {
    kCGSSpaceIncludesCurrent = 1 << 0,
    kCGSSpaceIncludesOthers = 1 << 1,
    kCGSSpaceIncludesUser = 1 << 2,
    kCGSAllSpacesMask = kCGSSpaceIncludesCurrent | kCGSSpaceIncludesOthers | kCGSSpaceIncludesUser,
} CGSSpaceMask;

extern CGSConnectionID CGSMainConnectionID(void);

// ディスプレイごとの Space 一覧(NSArray<NSDictionary>: "Display Identifier", "Spaces", "Current Space")
extern CFArrayRef CGSCopyManagedDisplaySpaces(CGSConnectionID cid);

// 指定ウィンドウ群が属する Space の ID 一覧
extern CFArrayRef CGSCopySpacesForWindows(CGSConnectionID cid, CGSSpaceMask mask, CFArrayRef windowIDs);

// AXUIElement → CGWindowID の対応付け(AX 操作対象と CGWindowList を結合する要)
extern AXError _AXUIElementGetWindow(AXUIElementRef element, uint32_t *windowID);

#endif
