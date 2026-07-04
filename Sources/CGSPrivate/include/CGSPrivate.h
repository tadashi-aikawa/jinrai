#ifndef CGS_PRIVATE_H
#define CGS_PRIVATE_H

#include <CoreFoundation/CoreFoundation.h>
#include <ApplicationServices/ApplicationServices.h>

// 非公開 CoreGraphicsServices(SkyLight)API の宣言。
// Hammerspoon と同じ手法で、実体は
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

// ウィンドウ単位でプロセスを最前面化する(AltTab と同じ手法)。
// 別 Space のウィンドウを指定すると macOS がその Space へ自動的に切り替える
extern CGError _SLPSSetFrontProcessWithOptions(ProcessSerialNumber *psn, uint32_t windowID, uint32_t mode);

// window server へ低レベルイベントを直接送る(対象ウィンドウを key window にする用途)
extern CGError SLPSPostEventRecordTo(ProcessSerialNumber *psn, uint8_t *bytes);

// pid → ProcessSerialNumber。GetProcessForPID は deprecated だが
// _SLPSSetFrontProcessWithOptions が PSN を要求するため代替がない
static inline OSStatus CGSGetProcessForPID(pid_t pid, ProcessSerialNumber *psn) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return GetProcessForPID(pid, psn);
#pragma clang diagnostic pop
}

#endif
