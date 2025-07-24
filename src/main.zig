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

const sampleRate = 44100.0;

const freq = 440.0;
var phase: f64 = 0.0;

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

    const buffer = &ioData.*.mBuffers[0];

    const alignedPtr: *f32 = @alignCast(@ptrCast(buffer.mData.?));
    const samplePtr: [*]f32 = @ptrCast(alignedPtr);
    const samples = samplePtr[0..inNumberFrames];

    for (samples) |*sample| {
        sample.* = @floatCast(std.math.sin(phase) * 0.2);
        // Move phase with angular velocity.
        // 2 * PI * freq to figure out radians/second. Hz expresses rotations pr second. 2*PI radians is one full cycle of a rotation.
        // Divide by sampleRate because this is the rate of samples we are outputting each second. So we divide by this number because we want to figure out the phase increment for one sample.
        phase += 2.0 * std.math.pi * freq / sampleRate;

        // If phase is bigger than 2*PI, wrap it around. This is because we do not want phase to grow very large. Sin is periodic every 2*PI...
        if (phase >= 2.0 * std.math.pi) {
            phase -= 2.0 * std.math.pi;
        }
    }

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
    _ = c.AudioComponentInstanceNew(comp, &audioInstance);

    if (audioInstance == null) {
        std.debug.print("Could not create audio instance", .{});
        return;
    }

    defer _ = c.AudioComponentInstanceDispose(audioInstance);

    const input = c.AURenderCallbackStruct{ .inputProc = audioRenderCallback, .inputProcRefCon = null };

    if (c.AudioUnitSetProperty(
        audioInstance,
        c.kAudioUnitProperty_SetRenderCallback,
        c.kAudioUnitScope_Input,
        0,
        &input,
        @sizeOf(@TypeOf(input)),
    ) != 0) {
        std.debug.print("Could not set property on audio unit", .{});
        return;
    }

    var streamDesc = c.AudioStreamBasicDescription{
        // An identifier specifying the general audio data format in the stream.
        .mFormatID = c.kAudioFormatLinearPCM,
        // Format-specific flags to specify details of the format.
        .mFormatFlags = c.kAudioFormatFlagIsFloat | c.kAudioFormatFlagIsPacked,
        // The number of frames per second of the data in the stream, when playing the stream at normal speed.
        .mSampleRate = sampleRate,
        // The number of bits for one audio sample.
        .mBitsPerChannel = 32,
        // The number of bytes from the start of one frame to the start of the next frame in an audio buffer.
        .mBytesPerFrame = 4,
        // The number of channels in each frame of audio data.
        .mChannelsPerFrame = 1,
        // The number of bytes in a packet of audio data.
        .mBytesPerPacket = 4,
        // The number of frames in a packet of audio data.
        .mFramesPerPacket = 1,
        // The amount to pad the structure to force an even 8-byte alignment.
        .mReserved = 0,
    };

    if (c.AudioUnitSetProperty(
        audioInstance,
        c.kAudioUnitProperty_StreamFormat,
        c.kAudioUnitScope_Input,
        0,
        &streamDesc,
        @sizeOf(@TypeOf(streamDesc)),
    ) != 0) {
        std.debug.print("Could not set stream basic description on audio unit", .{});
        return;
    }

    if (c.AudioUnitInitialize(audioInstance) != 0) {
        std.debug.print("Could not initialize audio unit", .{});
        return;
    }

    if (c.AudioOutputUnitStart(audioInstance) != 0) {
        std.debug.print("Could not start audio unit", .{});
        return;
    }

    std.debug.print("Playing.. Press Cmd+C to stop\n", .{});

    while (true) {
        std.time.sleep(1 * std.time.ns_per_s);
        std.debug.print("Phase: {}\n", .{phase});
    }
}
