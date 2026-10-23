const std = @import("std");
const windows = std.os.windows;

const HWND = windows.HWND;
const BOOL = windows.BOOL;
const LPCWSTR = windows.LPCWSTR;
const UINT = windows.UINT;
extern "kernel32" fn Sleep(dwMilliseconds: u32) callconv(.winapi) void;
// Windows API constants
const SW_HIDE: INT = 0;
const SW_SHOWNOACTIVATE: INT = 4;

const INT = i32;

// Windows API functions
extern "user32" fn FindWindowW(
    lpClassName: LPCWSTR,
    lpWindowName: ?LPCWSTR,
) callconv(.winapi) ?HWND;

extern "user32" fn ShowWindow(
    hWnd: HWND,
    nCmdShow: INT,
) callconv(.winapi) BOOL;

pub fn main() void {
    shortLoop();
}

fn shortLoop() void {
    while (true) {
        // Match the uploaded Python script: hide the taskbars.
        const should_show = false;

        // Find primary and secondary taskbars.
        const primary = FindWindowW(
            std.unicode.utf8ToUtf16LeStringLiteral("Shell_TrayWnd"),
            null,
        );

        const secondary = FindWindowW(
            std.unicode.utf8ToUtf16LeStringLiteral("Shell_SecondaryTrayWnd"),
            null,
        );

        // Enforce taskbar visibility.
        const command: INT = if (should_show) SW_SHOWNOACTIVATE else SW_HIDE;

        if (primary) |hwnd| {
            _ = ShowWindow(hwnd, command);
        }

        if (secondary) |hwnd| {
            _ = ShowWindow(hwnd, command);
        }

        // Sleep for 30 milliseconds.
        Sleep(30);
    }
}

