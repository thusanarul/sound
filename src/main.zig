const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("sound_lib");

const c = @cImport({
    @cInclude("AudioToolbox/AudioToolbox.h");
    @cInclude("CoreAudio/CoreAudio.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

pub fn main() !void {
    std.debug.print("Hello!\n", .{});
    const allocator = c.kCFAllocatorDefault;
    var sound_id: c.SystemSoundID = 1007;

    const url_string = "/Users/thusanarul/Downloads/acip-rap/01_30s.wav";
    const path = c.CFStringCreateWithCString(allocator, url_string, c.kCFStringEncodingUTF8);

    std.debug.print("path: {?}\n", .{path});

    const url = c.CFURLCreateWithFileSystemPath(allocator, path, c.kCFURLPOSIXPathStyle, @as(u8, 0));

    if (url == null) {
        return;
    }

    const error_ptr = null; // or you can provide a pointer to CFErrorRef variable to get error info
    const exists = c.CFURLResourceIsReachable(url, error_ptr);

    if (exists == 1) {
        std.debug.print("File exists!\n", .{});
    } else {
        std.debug.print("File does NOT exist or is not reachable\n", .{});
        return;
    }

    const status = c.AudioServicesCreateSystemSoundID(url, &sound_id);

    if (status != 0) {
        std.debug.print("Failed to create sound ID: {d}\n", .{status});
        return;
    }

    _ = c.AudioServicesPlaySystemSound(sound_id);

    std.time.sleep(30 * std.time.ns_per_s);
}
