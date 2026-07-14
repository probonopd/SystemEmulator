#import "GSUTMConfiguration.h"

NSString *const GSUTMErrorDomain = @"GSUTMErrorDomain";

@implementation GSUTMConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        _name = @"Virtual Machine";
        _architecture = @"x86_64";
        _target = @"q35";
        _cpu = @"default";
        _memorySize = 512;
        _cpuCount = 1;
        _bootDevice = @"disk";
        _networkCard = @"rtl8139";
        _networkEnabled = YES;
        _soundCard = @"ac97";
        _soundEnabled = YES;
        _drives = [[NSMutableArray alloc] init];
        _rawPlist = [[NSDictionary alloc] init];
        _consoleFont = @"Menlo";
        _consoleFontSize = 12;
        _consoleTheme = @"Default";
        _displayUpscaler = @"linear";
        _displayDownscaler = @"linear";
    }
    return self;
}

- (instancetype)initWithPlist:(NSDictionary *)plist
{
    self = [self init];
    if (self) {
        [_rawPlist release];
        _rawPlist = [plist copy];

        id info = plist[@"Info"] ?: plist[@"Information"];
        if ([info isKindOfClass:[NSDictionary class]]) {
            if (info[@"Name"]) _name = info[@"Name"];
            if (info[@"Icon"]) _iconName = info[@"Icon"];
            if (info[@"Notes"]) _notes = info[@"Notes"];
        }

        NSDictionary *system = plist[@"System"];
        if (system) {
            if (system[@"Architecture"]) _architecture = system[@"Architecture"];
            if (system[@"Target"]) _target = system[@"Target"];
            if (system[@"CPU"]) _cpu = system[@"CPU"];
            if (system[@"Memory"]) _memorySize = [system[@"Memory"] unsignedIntegerValue];
            if (system[@"MemorySize"]) _memorySize = [system[@"MemorySize"] unsignedIntegerValue];
            if (system[@"CPUCount"]) _cpuCount = [system[@"CPUCount"] unsignedIntegerValue];
            if (system[@"BootDevice"]) _bootDevice = system[@"BootDevice"];
        }

        id drives = plist[@"Drives"] ?: plist[@"Drive"];
        if ([drives isKindOfClass:[NSArray class]]) {
            [_drives release];
            _drives = [[NSMutableArray alloc] initWithCapacity:[drives count]];
            for (NSDictionary *d in drives) {
                [_drives addObject:[[d mutableCopy] autorelease]];
            }
        }

        id networkObj = plist[@"Networking"] ?: plist[@"Network"];
        if ([networkObj isKindOfClass:[NSDictionary class]]) {
            if (networkObj[@"NetworkCard"]) _networkCard = networkObj[@"NetworkCard"];
            if (networkObj[@"NetworkEnabled"]) _networkEnabled = [networkObj[@"NetworkEnabled"] boolValue];
        } else if ([networkObj isKindOfClass:[NSArray class]] && [networkObj count] > 0) {
            id first = [networkObj objectAtIndex:0];
            if ([first isKindOfClass:[NSDictionary class]]) {
                NSString *hw = [first objectForKey:@"Hardware"];
                if (hw) _networkCard = hw;
                _networkEnabled = YES;
            }
        }

        id soundObj = plist[@"Sound"];
        if ([soundObj isKindOfClass:[NSDictionary class]]) {
            if (soundObj[@"SoundCard"]) _soundCard = soundObj[@"SoundCard"];
            if (soundObj[@"SoundEnabled"]) _soundEnabled = [soundObj[@"SoundEnabled"] boolValue];
        } else if ([soundObj isKindOfClass:[NSArray class]] && [soundObj count] > 0) {
            id first = [soundObj objectAtIndex:0];
            if ([first isKindOfClass:[NSDictionary class]]) {
                NSString *hw = [first objectForKey:@"Hardware"];
                if (hw) _soundCard = hw;
                _soundEnabled = YES;
            }
        }

        id sharing = plist[@"Sharing"];
        if ([sharing isKindOfClass:[NSDictionary class]]) {
            if (sharing[@"ClipboardSharing"]) _clipboardSharing = [sharing[@"ClipboardSharing"] boolValue];
            if (sharing[@"DirectorySharing"]) _directorySharing = [sharing[@"DirectorySharing"] boolValue];
        }

        id input = plist[@"Input"];
        if ([input isKindOfClass:[NSDictionary class]]) {
            if (input[@"InputLegacy"]) _inputLegacy = [input[@"InputLegacy"] boolValue];
        }

        id displayObj = plist[@"Display"];
        if ([displayObj isKindOfClass:[NSDictionary class]]) {
            NSDictionary *display = displayObj;
            if (display[@"ConsoleFont"]) _consoleFont = display[@"ConsoleFont"];
            if (display[@"ConsoleFontSize"]) _consoleFontSize = [display[@"ConsoleFontSize"] intValue];
            if (display[@"ConsoleTheme"]) _consoleTheme = display[@"ConsoleTheme"];
            if (display[@"DisplayUpscaler"]) _displayUpscaler = display[@"DisplayUpscaler"];
            if (display[@"DisplayDownscaler"]) _displayDownscaler = display[@"DisplayDownscaler"];
        }

        id debugObj = plist[@"Debug"];
        if ([debugObj isKindOfClass:[NSDictionary class]]) {
            NSString *args = [debugObj objectForKey:@"Arguments"];
            if (args) _extraArguments = args;
        }
    }
    return self;
}

- (NSString *)targetString
{
    if ([_target isEqualToString:@"pc-"] || [_target isEqualToString:@"pc"]) return @"pc";
    if ([_target isEqualToString:@"pc-i440fx-"]) return @"pc";
    return _target;
}

- (NSString *)qemuBinary
{
    NSString *name;
    if ([_architecture isEqualToString:@"aarch64"] || [_architecture hasPrefix:@"arm64"])
        name = @"qemu-system-aarch64";
    else
        name = @"qemu-system-x86_64";
    NSArray *paths = @[@"/bin", @"/usr/bin", @"/usr/local/bin", @"/opt/local/bin",
                       @"/opt/homebrew/bin", @"/run/current-system/sw/bin"];
    for (NSString *dir in paths) {
        NSString *full = [dir stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:full])
            return full;
    }
    return name;
}

- (NSString *)driveInterfaceDevice:(NSString *)interface imageType:(NSString *)imageType
{
    NSString *iface = [interface lowercaseString];
    BOOL isCd = [imageType isEqualToString:@"cd"] || [imageType isEqualToString:@"CD"];
    if ([iface isEqualToString:@"ide"]) return isCd ? @"ide-cd" : @"ide-hd";
    if ([iface isEqualToString:@"virtio"] || [iface isEqualToString:@"VirtIO"]) return @"virtio-blk-pci";
    if ([iface isEqualToString:@"scsi"]) return isCd ? @"scsi-cd" : @"scsi-hd";
    if ([iface isEqualToString:@"nvme"]) return @"nvme";
    if ([iface isEqualToString:@"usb"] || [iface isEqualToString:@"USB"]) return @"usb-storage";
    return isCd ? @"ide-cd" : @"ide-hd";
}

#pragma mark - Device Availability

- (NSString *)_qemuBinaryForArch:(NSString *)arch
{
    if ([arch isEqualToString:@"aarch64"] || [arch hasPrefix:@"arm64"])
        return @"qemu-system-aarch64";
    return @"qemu-system-x86_64";
}

- (NSSet *)_availableDevicesForArch:(NSString *)arch
{
    static NSMutableDictionary *cache = nil;
    if (!cache) cache = [[NSMutableDictionary alloc] init];
    NSSet *cached = [cache objectForKey:arch];
    if (cached) return cached;

    NSString *binary = [self _qemuBinaryForArch:arch];
    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath:binary];
    [task setArguments:@[@"-device", @"help"]];
    NSPipe *pipe = [NSPipe pipe];
    [task setStandardOutput:pipe];
    [task setStandardError:[NSPipe pipe]];
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *e) {
        [task release];
        return nil;
    }
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    [task release];

    NSMutableSet *devices = [NSMutableSet set];
    for (NSString *line in [output componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"name \""]) {
            NSRange r1 = [line rangeOfString:@"\""];
            NSRange r2 = [[line substringFromIndex:r1.location + 1] rangeOfString:@"\""];
            if (r1.location != NSNotFound && r2.location != NSNotFound) {
                NSString *name = [line substringWithRange:NSMakeRange(r1.location + 1, r2.location)];
                [devices addObject:name];
                /* Also check for alias */
                NSRange aliasR = [line rangeOfString:@"alias \""];
                if (aliasR.location != NSNotFound) {
                    NSString *rest = [line substringFromIndex:aliasR.location + 7];
                    NSRange aEnd = [rest rangeOfString:@"\""];
                    if (aEnd.location != NSNotFound)
                        [devices addObject:[rest substringToIndex:aEnd.location]];
                }
            }
        }
    }
    [cache setObject:devices forKey:arch];
    return devices;
}

- (BOOL)isDeviceAvailable:(NSString *)device arch:(NSString *)arch
{
    NSSet *devices = [self _availableDevicesForArch:arch];
    return [devices containsObject:device];
}

- (NSString *)availableDeviceFor:(NSString *)device arch:(NSString *)arch
{
    if ([self isDeviceAvailable:device arch:arch]) return device;
    /* Try fallbacks */
    NSDictionary *fallbacks = @{
        @"virtio-ramfb": @[@"VGA", @"virtio-vga", @"ramfb", @"cirrus-vga"],
        @"virtio-ramfb-gl": @[@"ramfb", @"VGA"],
        @"virtio-vga": @[@"VGA", @"cirrus-vga"],
        @"virtio-gpu-pci": @[@"VGA", @"ramfb", @"cirrus-vga"],
        @"intel-hda": @[@"ac97"],
        @"virtio-net-pci": @[@"e1000", @"rtl8139"],
        @"virtio-blk-pci": @[@"ide-hd"],
        @"nec-usb-xhci": @[@"usb-ehci", @"piix3-usb-uhci"],
    };
    NSArray *fblist = [fallbacks objectForKey:device];
    for (NSString *fb in fblist) {
        if ([self isDeviceAvailable:fb arch:arch]) {
            NSLog(@"WARNING: Device '%@' not available in this QEMU build. Using '%@' instead.", device, fb);
            return fb;
        }
    }
    NSLog(@"WARNING: Device '%@' and all fallbacks not available. Using default.", device);
    return device;
}

- (NSString *)networkDeviceName
{
    if ([_networkCard isEqualToString:@"rtl8139"]) return @"rtl8139";
    if ([_networkCard isEqualToString:@"e1000"]) return @"e1000";
    if ([_networkCard isEqualToString:@"virtio"]) return @"virtio-net-pci";
    if ([_networkCard isEqualToString:@"ne2k_pci"]) return @"ne2k_pci";
    if ([_architecture isEqualToString:@"aarch64"]) return @"virtio-net-pci";
    return @"e1000";
}

- (NSString *)diskImagePath
{
    for (NSDictionary *d in _drives) {
        if ([d[@"ImageType"] isEqualToString:@"disk"]) return d[@"ImagePath"] ?: @"";
    }
    return @"";
}

- (void)setDiskImagePath:(NSString *)path
{
    for (NSMutableDictionary *d in _drives) {
        if ([d[@"ImageType"] isEqualToString:@"disk"]) { d[@"ImagePath"] = path; return; }
    }
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                              @"disk", @"ImageType", @"ide", @"InterfaceType",
                              path ?: @"", @"ImagePath", nil];
    [_drives addObject:d];
}

- (NSString *)cdromImagePath
{
    for (NSDictionary *d in _drives) {
        if ([d[@"ImageType"] isEqualToString:@"cd"]) return d[@"ImagePath"] ?: @"";
    }
    return @"";
}

- (void)setCdromImagePath:(NSString *)path
{
    for (NSMutableDictionary *d in _drives) {
        if ([d[@"ImageType"] isEqualToString:@"cd"]) { d[@"ImagePath"] = path; return; }
    }
    if ([path length] > 0) {
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                  @"cd", @"ImageType", @"ide", @"InterfaceType",
                                  path, @"ImagePath", nil];
        [_drives addObject:d];
    }
}

- (void)resolveDrivePathsWithBaseURL:(NSURL *)baseURL
{
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSMutableDictionary *drive in _drives) {
        NSString *path = drive[@"ImagePath"];
        if (!path || [path length] == 0) continue;
        if ([path hasPrefix:@"~"]) { drive[@"ImagePath"] = [path stringByExpandingTildeInPath]; continue; }
        if ([path isAbsolutePath]) {
            if ([fm isReadableFileAtPath:path]) continue;
            /* Absolute path doesn't exist — try resolving filename relative to bundle */
            NSString *file = [path lastPathComponent];
            for (NSString *sub in @[@"Data", @"Images", @""]) {
                NSString *candidate = [[baseURL URLByAppendingPathComponent:sub isDirectory:YES]
                                        URLByAppendingPathComponent:file].path;
                if ([fm isReadableFileAtPath:candidate]) { drive[@"ImagePath"] = candidate; break; }
            }
            continue;
        }
        for (NSString *sub in @[@"Data", @"Images", @""]) {
            NSString *candidate = [[baseURL URLByAppendingPathComponent:sub isDirectory:YES]
                                    URLByAppendingPathComponent:path].path;
            if ([fm isReadableFileAtPath:candidate]) { drive[@"ImagePath"] = candidate; break; }
        }
    }
}

- (NSString *)_uuidString
{
    id info = _rawPlist[@"Information"] ?: _rawPlist[@"Info"];
    if ([info isKindOfClass:[NSDictionary class]]) return [info objectForKey:@"UUID"];
    return nil;
}

- (NSArray<NSString *> *)qemuArguments
{
    NSMutableArray *args = [NSMutableArray array];
    NSString *uuid = [self _uuidString] ?: @"00000000-0000-0000-0000-000000000000";

    /* -S removed: VM starts immediately (no QMP continue sent) */

    /* === 2. SPICE === */
    [args addObject:@"-spice"];
    [args addObject:[NSString stringWithFormat:@"unix=on,addr=%@.spice,disable-ticketing=on,image-compression=off,playback-compression=off,streaming-video=off,gl=off", uuid]];

    /* === 3. QMP Monitor === */
    [args addObject:@"-chardev"];
    [args addObject:[NSString stringWithFormat:@"spiceport,name=org.qemu.monitor.qmp.0,id=org.qemu.monitor.qmp"]];
    [args addObject:@"-mon"];
    [args addObject:@"chardev=org.qemu.monitor.qmp,mode=control"];

    /* === 4. -nodefaults -vga none -display sdl === */
    [args addObject:@"-nodefaults"];
    [args addObject:@"-vga"];
    [args addObject:@"none"];
    [args addObject:@"-display"];
    [args addObject:@"sdl"];

    /* === 5. Network === */
    id networkArr = [_rawPlist objectForKey:@"Network"];
    NSDictionary *netConfig = nil;
    if ([networkArr isKindOfClass:[NSArray class]] && [networkArr count] > 0) {
        id first = [networkArr objectAtIndex:0];
        if ([first isKindOfClass:[NSDictionary class]]) netConfig = first;
    } else if ([networkArr isKindOfClass:[NSDictionary class]]) netConfig = networkArr;
    NSString *netHw = netConfig ? ([netConfig objectForKey:@"Hardware"] ?: @"virtio-net-pci") : @"e1000";
    NSString *macAddr = netConfig ? ([netConfig objectForKey:@"MacAddress"] ?: @"") : @"";
    netHw = [self availableDeviceFor:netHw arch:_architecture];
    if ([macAddr length] > 0) {
        [args addObject:@"-device"];
        [args addObject:[NSString stringWithFormat:@"%@,mac=%@,netdev=net0", netHw, macAddr]];
    } else {
        [args addObject:@"-device"];
        [args addObject:[NSString stringWithFormat:@"%@,netdev=net0", netHw]];
    }

    /* Netdev mode: shared/user/bridged */
    NSString *netMode = netConfig ? ([netConfig objectForKey:@"Mode"] ?: @"shared") : @"shared";
    if ([netMode isEqualToString:@"shared"]) {
        [args addObject:@"-netdev"];
        [args addObject:@"user,id=net0"];
    } else if ([netMode isEqualToString:@"bridged"]) {
        NSString *iface = [netConfig objectForKey:@"BridgeInterface"] ?: @"eth0";
        [args addObject:@"-netdev"];
        [args addObject:[NSString stringWithFormat:@"bridge,id=net0,br=%@", iface]];
    } else {
        [args addObject:@"-netdev"];
        [args addObject:@"user,id=net0"];
    }

    /* === 6. Display === */
    id displayArr = [_rawPlist objectForKey:@"Display"];
    NSString *displayDev = @"virtio-ramfb";
    if ([displayArr isKindOfClass:[NSArray class]] && [displayArr count] > 0) {
        id first = [displayArr objectAtIndex:0];
        if ([first isKindOfClass:[NSDictionary class]]) {
            NSString *hw = [first objectForKey:@"Hardware"];
            if (hw) displayDev = hw;
        }
    } else if ([displayArr isKindOfClass:[NSDictionary class]]) {
        NSString *hw = [displayArr objectForKey:@"Hardware"];
        if (hw) displayDev = hw;
    }
    displayDev = [self availableDeviceFor:displayDev arch:_architecture];
    [args addObject:@"-device"];
    [args addObject:displayDev];

    /* === 7. CPU + SMP === */
    id qemuSection = [_rawPlist objectForKey:@"QEMU"];
    BOOL wantsHost = [_cpu isEqualToString:@"host"];
    if (!wantsHost && [qemuSection isKindOfClass:[NSDictionary class]])
        wantsHost = [qemuSection[@"Hypervisor"] boolValue];
    if (wantsHost) {
        [args addObject:@"-cpu"];
        [args addObject:@"host"];
    } else if (![_cpu isEqualToString:@"default"]) {
        [args addObject:@"-cpu"];
        [args addObject:_cpu];
    } else if ([_architecture isEqualToString:@"aarch64"]) {
        [args addObject:@"-cpu"];
        [args addObject:@"cortex-a72"];
    }

    NSUInteger ncpu = _cpuCount > 0 ? _cpuCount : 1;
    [args addObject:@"-smp"];
    [args addObject:[NSString stringWithFormat:@"cpus=%lu,sockets=1,cores=%lu,threads=1",
                     (unsigned long)ncpu, (unsigned long)ncpu]];

    /* === 8. Machine + Acceleration === */
    [args addObject:@"-machine"];
    [args addObject:[self targetString]];

    /* Acceleration: prefer KVM (Linux), fall back to TCG */
    BOOL wantsHvf = NO;
    if ([qemuSection isKindOfClass:[NSDictionary class]])
        wantsHvf = [qemuSection[@"Hypervisor"] boolValue];
    if (wantsHvf) {
        if ([[NSFileManager defaultManager] isReadableFileAtPath:@"/dev/kvm"]) {
            [args addObject:@"-accel"];
            [args addObject:@"kvm"];
        } else {
            [args addObject:@"-accel"];
            [args addObject:@"tcg"];
        }
    } else {
        [args addObject:@"-accel"];
        [args addObject:@"tcg"];
    }

    /* === 9. Architecture: UEFI pflash === */
    BOOL hasUefi = NO;
    if ([qemuSection isKindOfClass:[NSDictionary class]])
        hasUefi = [qemuSection[@"UEFIBoot"] boolValue];
    if (hasUefi) {
        NSString *codeFile = [NSString stringWithFormat:@"/usr/share/qemu/edk2-%@-code.fd",
                              [_architecture isEqualToString:@"aarch64"] ? @"aarch64" : @"x86_64"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm isReadableFileAtPath:codeFile]) {
    [args addObject:@"-drive"];
    [args addObject:[NSString stringWithFormat:@"if=pflash,format=raw,unit=0,file.filename=%@,file.locking=off,readonly=on", codeFile]];
        }
        NSString *varsFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"efi_vars.fd"];
        if (![fm fileExistsAtPath:varsFile]) {
            NSString *template = [NSString stringWithFormat:@"/usr/share/qemu/edk2-%@-vars.fd",
                                   [_architecture isEqualToString:@"aarch64"] ? @"aarch64" : @"x86_64"];
            if ([fm isReadableFileAtPath:template])
                [fm copyItemAtPath:template toPath:varsFile error:NULL];
        }
        if ([fm isReadableFileAtPath:varsFile])
    [args addObject:@"-drive"];
    [args addObject:[NSString stringWithFormat:@"if=pflash,unit=1,file.filename=%@", varsFile]];
    }

    /* === 10. Memory === */
    [args addObject:@"-m"];
    [args addObject:[NSString stringWithFormat:@"%lu", (unsigned long)(unsigned long)_memorySize]];

    /* === 11. Sound === */
    id soundArr = [_rawPlist objectForKey:@"Sound"];
    NSString *soundHw = nil;
    if ([soundArr isKindOfClass:[NSArray class]] && [soundArr count] > 0) {
        id first = [soundArr objectAtIndex:0];
        if ([first isKindOfClass:[NSDictionary class]]) soundHw = [first objectForKey:@"Hardware"];
    } else if ([soundArr isKindOfClass:[NSDictionary class]]) {
        soundHw = [soundArr objectForKey:@"Hardware"] ?: [soundArr objectForKey:@"SoundCard"];
    }
    if (soundHw || _soundEnabled) {
        if (!soundHw) soundHw = _soundCard;
        soundHw = [self availableDeviceFor:soundHw arch:_architecture];
    [args addObject:@"-audiodev"];
    [args addObject:@"alsa,id=audio0"];
        if ([soundHw isEqualToString:@"intel-hda"]) {
            [args addObject:@"-device"];
            [args addObject:soundHw];
            [args addObject:@"-device"];
            [args addObject:@"hda-duplex,audiodev=audio0"];
        } else {
            [args addObject:@"-device"];
            [args addObject:[NSString stringWithFormat:@"%@,audiodev=audio0", soundHw]];
        }
    }

    /* === 12. USB === */
    NSString *usbController = [self availableDeviceFor:@"nec-usb-xhci" arch:_architecture];
    if ([_target isEqualToString:@"virt"] || [_architecture isEqualToString:@"aarch64"]) {
        [args addObject:@"-device"];
        [args addObject:[NSString stringWithFormat:@"%@,id=usb-bus", usbController]];
    } else {
        [args addObject:@"-usb"];
    }

    [args addObject:@"-device"];
    [args addObject:@"usb-tablet,bus=usb-bus.0"];
    [args addObject:@"-device"];
    [args addObject:@"usb-mouse,bus=usb-bus.0"];
    [args addObject:@"-device"];
    [args addObject:@"usb-kbd,bus=usb-bus.0"];

    /* USB redirection */
    id inputSection = [_rawPlist objectForKey:@"Input"];
    NSInteger maxShare = 3;
    if ([inputSection isKindOfClass:[NSDictionary class]]) {
        if ([inputSection objectForKey:@"MaximumUsbShare"])
            maxShare = [[inputSection objectForKey:@"MaximumUsbShare"] integerValue];
    }
    if (maxShare > 0) {
    [args addObject:@"-device"];
    [args addObject:@"qemu-xhci,id=usb-controller-0"];
        for (int i = 0; i < maxShare && i < 3; i++) {
            [args addObject:@"-chardev"];
            [args addObject:[NSString stringWithFormat:@"spicevmc,name=usbredir,id=usbredirchardev%d", i]];
            [args addObject:@"-device"];
            [args addObject:[NSString stringWithFormat:@"usb-redir,chardev=usbredirchardev%d,id=usbredirdev%d,bus=usb-controller-0.0", i, i]];
        }
    }

    /* === 13. Drives === */
    int bootIdx = 0;
    for (NSDictionary *drive in _drives) {
        NSString *imagePath = drive[@"ImagePath"] ?: drive[@"ImageName"];
        NSString *imageType = drive[@"ImageType"] ?: @"disk";
        NSString *interface = drive[@"InterfaceType"] ?: drive[@"Interface"] ?: @"ide";
        NSString *identifier = drive[@"Identifier"];
        BOOL isCd = [imageType isEqualToString:@"CD"] || [imageType isEqualToString:@"cd"];
        BOOL isDisk = [imageType isEqualToString:@"Disk"] || [imageType isEqualToString:@"disk"];
        BOOL removable = [drive[@"Removable"] boolValue];
        BOOL readOnly = [drive[@"ReadOnly"] boolValue];
        NSString *driveId = identifier ? [NSString stringWithFormat:@"drive%@", identifier] :
                                         [NSString stringWithFormat:@"drive%d", bootIdx];

        /* A CD with no image path is still a removable device */
        BOOL actuallyRemovable = removable || (isCd && !imagePath);
        if (imagePath || actuallyRemovable) {
            NSString *dev = [self availableDeviceFor:[self driveInterfaceDevice:interface imageType:imageType] arch:_architecture];
            NSMutableString *devArg = [NSMutableString stringWithFormat:@"%@,drive=%@", dev, driveId];
            /* Only add removable=true for non-CD devices that are removable.
               CD device types (ide-cd, scsi-cd, usb-storage with CD) already imply removable. */
            if (!isCd && actuallyRemovable) [devArg appendString:@",removable=true"];
            [devArg appendString:[NSString stringWithFormat:@",bootindex=%d", bootIdx]];
            if (isDisk && [identifier length] > 0) {
                NSString *serial = [[identifier stringByReplacingOccurrencesOfString:@"-" withString:@""] substringToIndex:20];
                [devArg appendString:[NSString stringWithFormat:@",serial=%@", serial]];
            }
            if ([dev isEqualToString:@"usb-storage"]) [devArg appendString:@",bus=usb-bus.0"];
    [args addObject:@"-device"];
    [args addObject:devArg];

            NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=none,media=%@,id=%@",
                                          isCd ? @"cdrom" : @"disk", driveId];
            if (imagePath) {
                [driveArg appendString:[NSString stringWithFormat:@",file.filename=%@", imagePath]];
            } else if (isCd || actuallyRemovable) {
                [driveArg appendString:@",file.filename=/dev/null"];
            }
            if (isCd || actuallyRemovable || readOnly) [driveArg appendString:@",file.locking=off,readonly=on"];
            if (isDisk) [driveArg appendString:@",discard=unmap,detect-zeroes=unmap"];
    [args addObject:@"-drive"];
    [args addObject:driveArg];
            bootIdx++;
        }
    }

    /* === 14. Sharing (virtio-serial + agents) === */
    [args addObject:@"-device"];
    [args addObject:@"virtio-serial"];
    [args addObject:@"-device"];
    [args addObject:@"virtserialport,bus=virtio-serial-bus.0,chardev=org.qemu.guest_agent,name=org.qemu.guest_agent.0"];
    [args addObject:@"-chardev"];
    [args addObject:@"spiceport,name=org.qemu.guest_agent.0,id=org.qemu.guest_agent"];
    [args addObject:@"-device"];
    [args addObject:@"virtserialport,bus=virtio-serial-bus.0,chardev=vdagent,name=com.redhat.spice.0"];
    [args addObject:@"-chardev"];
    [args addObject:@"spicevmc,id=vdagent,debug=0,name=vdagent"];
    [args addObject:@"-device"];
    [args addObject:@"virtserialport,bus=virtio-serial-bus.0,chardev=charchannel1,id=channel1,name=org.spice-space.webdav.0"];
    [args addObject:@"-chardev"];
    [args addObject:@"spiceport,name=org.spice-space.webdav.0,id=charchannel1"];

    /* === 15. Name and UUID === */
    [args addObject:@"-name"];
    [args addObject:_name ?: @"Virtual Machine"];
    [args addObject:@"-uuid"];
    [args addObject:uuid];

    /* === 16. RNG === */
    BOOL hasRng = NO;
    if ([qemuSection isKindOfClass:[NSDictionary class]]) hasRng = [qemuSection[@"RNGDevice"] boolValue];
    if (hasRng) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-rng-pci"];
    }

    /* === 17. Extra arguments === */
    if ([_extraArguments length] > 0) {
        NSArray *extra = [_extraArguments componentsSeparatedByCharactersInSet:
                          [NSCharacterSet whitespaceCharacterSet]];
        for (NSString *arg in extra) {
            if ([arg length] > 0) [args addObject:arg];
        }
    }

    return args;
}

#pragma mark - Persistence

- (BOOL)saveToURL:(NSURL *)url error:(NSError **)error
{
    NSMutableDictionary *plist = [NSMutableDictionary dictionary];
    plist[@"ConfigurationVersion"] = @2;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[@"Name"] = _name;
    if (_iconName) info[@"Icon"] = _iconName;
    info[@"IconCustom"] = @(_iconName != nil);
    if (_notes) info[@"Notes"] = _notes;
    plist[@"Info"] = info;
    NSMutableDictionary *system = [NSMutableDictionary dictionary];
    system[@"Architecture"] = _architecture;
    system[@"Target"] = _target;
    system[@"CPU"] = _cpu;
    system[@"Memory"] = @(_memorySize);
    system[@"CPUCount"] = @(_cpuCount);
    system[@"BootDevice"] = _bootDevice;
    plist[@"System"] = system;
    /* Convert absolute drive paths to relative to Images/ */
    NSMutableArray *savedDrives = [NSMutableArray arrayWithCapacity:[_drives count]];
    for (NSDictionary *drive in _drives) {
        NSMutableDictionary *d = [[drive mutableCopy] autorelease];
        NSString *path = d[@"ImagePath"];
        if ([path isAbsolutePath]) {
            NSString *imagesPrefix = [[url URLByAppendingPathComponent:@"Images" isDirectory:YES] path];
            if ([path hasPrefix:imagesPrefix]) {
                NSString *rel = [path substringFromIndex:[imagesPrefix length] + 1];
                [d setObject:rel forKey:@"ImagePath"];
                [d removeObjectForKey:@"ImageName"];
                [d setObject:rel forKey:@"ImageName"];
            }
        }
        [savedDrives addObject:d];
    }
    plist[@"Drives"] = savedDrives;
    NSMutableDictionary *network = [NSMutableDictionary dictionary];
    network[@"NetworkCard"] = _networkCard;
    network[@"NetworkEnabled"] = @(_networkEnabled);
    plist[@"Networking"] = network;
    NSMutableDictionary *sound = [NSMutableDictionary dictionary];
    sound[@"SoundCard"] = _soundCard;
    sound[@"SoundEnabled"] = @(_soundEnabled);
    plist[@"Sound"] = sound;
    NSMutableDictionary *sharing = [NSMutableDictionary dictionary];
    sharing[@"ClipboardSharing"] = @(_clipboardSharing);
    sharing[@"DirectorySharing"] = @(_directorySharing);
    plist[@"Sharing"] = sharing;
    NSMutableDictionary *input = [NSMutableDictionary dictionary];
    input[@"InputLegacy"] = @(_inputLegacy);
    plist[@"Input"] = input;
    NSMutableDictionary *display = [NSMutableDictionary dictionary];
    display[@"ConsoleFont"] = _consoleFont;
    display[@"ConsoleFontSize"] = @(_consoleFontSize);
    display[@"ConsoleTheme"] = _consoleTheme;
    display[@"DisplayUpscaler"] = _displayUpscaler;
    display[@"DisplayDownscaler"] = _displayDownscaler;
    plist[@"Display"] = display;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist
                                                              format:NSPropertyListXMLFormat_v1_0
                                                             options:0 error:error];
    if (!data) return NO;
    return [data writeToURL:url options:NSDataWritingAtomic error:error];
}

+ (instancetype)loadFromURL:(NSURL *)url error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfURL:url options:0 error:error];
    if (!data) return nil;
    NSDictionary *plist = [NSPropertyListSerialization propertyListWithData:data
                                    options:NSPropertyListImmutable format:NULL error:error];
    if (![plist isKindOfClass:[NSDictionary class]]) return nil;
    GSUTMConfiguration *config = [[self alloc] initWithPlist:plist];
    config.baseURL = [url URLByDeletingLastPathComponent];
    return config;
}

- (void)dealloc
{
    [_rawPlist release]; [_name release]; [_iconName release]; [_notes release];
    [_architecture release]; [_target release]; [_cpu release]; [_bootDevice release];
    [_drives release]; [_networkCard release]; [_soundCard release];
    [_consoleFont release]; [_consoleTheme release]; [_displayUpscaler release];
    [_displayDownscaler release]; [_extraArguments release]; [_baseURL release];
    [super dealloc];
}

@end
