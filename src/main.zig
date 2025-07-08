const std = @import("std");

/// This imports the separate module containing `root.zig`. Take a look in `build.zig` for details.
const lib = @import("sound_lib");

// NOTE: Would like to try to use AVFAudio high-level api for some stuff like finding audio component etc.
//       But, I get conflicting definitions of some variables defined by both :(
const c = @cImport({
    @cInclude("AudioToolbox/AudioToolbox.h");
    @cInclude("CoreAudio/CoreAudio.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

fn audioRenderCallback(
    // Custom data that you provided when registering your callback with the audio unit.
    inRefCon: ?*anyopaque,
    // Flags used to describe more about the context of this call (pre or post in the notify case for instance).
    ioActionFlags: [*c]c.AudioUnitRenderActionFlags,
    // The timestamp associated with this call of audio unit render.
    inTimeStamp: [*c]const c.AudioTimeStamp,
    // The bus number associated with this call of audio unit render.
    inBusNumber: c.UInt32,
    // The number of sample frames that will be represented in the audio data in the provided ioData parameter.
    inNumberFrames: c.UInt32,
    // The AudioBufferList that will be used to contain the rendered or provided audio data.
    ioData: [*c]c.AudioBufferList,
) callconv(.C) c.OSStatus {
    _ = inRefCon; // autofix
    _ = ioActionFlags; // autofix
    _ = inTimeStamp; // autofix
    _ = inBusNumber; // autofix
    _ = inNumberFrames; // autofix
    _ = ioData; // autofix

    return 0;
}

pub fn main() !void {
    std.debug.print("Play sounds!\n", .{});

    const desc: c.AudioComponentDescription = c.AudioComponentDescription{
        // A unique 4-byte code identifying the interface for the component.
        .componentType = c.kAudioUnitType_Output,
        // A 4-byte code that you can use to indicate the purpose of a component. For example, you could use lpas or lowp as a mnemonic indication that an audio unit is a low-pass filter.
        .componentSubType = c.kAudioUnitSubType_DefaultOutput,
        // The unique vendor identifier, registered with Apple, for the audio component.
        .componentManufacturer = c.kAudioUnitManufacturer_Apple,
        // Set this value to zero.
        .componentFlags = 0,
        // Set this value to zero.
        .componentFlagsMask = 0,
    };

    const comp = c.AudioComponentFindNext(null, &desc);

    if (comp == null) {
        std.debug.print("Audio component not found", .{});
        return;
    }

    var audioInstance: c.AudioComponentInstance = null;
    c.AudioComponentInstanceNew(comp, &audioInstance);

    if (audioInstance == null) {
        std.debug.print("Could not create audio instance", .{});
        return;
    }

    defer c.AudioComponentInstanceDispose(audioInstance);

    const input = c.AURenderCallbackStruct{ .inputProc = audioRenderCallback, .inputProcRefCon = null };

    if (c.AudioUnitSetProperty(
        audioInstance,
        c.kAudioUnitProperty_SetRenderCallback,
        c.kAudioUnitScope_Input,
        0,
        &input,
        @sizeOf(input),
    ) != 0) {
        std.debug.print("Could set property on audio unit", .{});
        return;
    }

    var streamDesc = c.AudioStreamBasicDescription{};
    _ = streamDesc; // autofix

    if (c.AudioUnitInitialize(audioInstance) != 0) {
        std.debug.print("Could initialize audio unit", .{});
        return;
    }

    std.time.sleep(30 * std.time.ns_per_s);
}
