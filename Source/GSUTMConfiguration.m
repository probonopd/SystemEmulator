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
    NSString *name = [NSString stringWithFormat:@"qemu-system-%@", _architecture];
    NSArray *paths = @[@"/bin", @"/usr/bin", @"/usr/local/bin", @"/opt/local/bin",
                       @"/opt/homebrew/bin", @"/run/current-system/sw/bin"];
    for (NSString *dir in paths) {
        NSString *full = [dir stringByAppendingPathComponent:name];
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:full])
            return full;
    }
    return name;
}

#pragma mark - Architecture Feature Flags

- (BOOL)_isSparc { return [_architecture hasPrefix:@"sparc"]; }
- (BOOL)_isM68k { return [_architecture isEqualToString:@"m68k"]; }
- (BOOL)_isPPC { return [_architecture isEqualToString:@"ppc"] || [_architecture isEqualToString:@"ppc64"]; }
- (BOOL)_isS390x { return [_architecture isEqualToString:@"s390x"]; }
- (BOOL)_isPcCompatible { return [_architecture isEqualToString:@"x86_64"] || [_architecture isEqualToString:@"i386"]; }

- (BOOL)_hasAgentSupport
{
    NSSet *noAgent = [NSSet setWithObjects:@"avr", @"m68k", @"microblaze", @"microblazeel",
                      @"ppc", @"ppc64", @"rx", @"sparc", @"sparc64", @"tricore", nil];
    return ![noAgent containsObject:_architecture];
}

- (BOOL)_hasUsbSupport
{
    NSSet *noUsb = [NSSet setWithObjects:@"s390x", @"sparc", @"sparc64", @"m68k", nil];
    return ![noUsb containsObject:_architecture];
}

- (BOOL)_hasSharingSupport
{
    NSSet *noSharing = [NSSet setWithObjects:@"sparc", @"sparc64", nil];
    return ![noSharing containsObject:_architecture];
}

- (BOOL)_isClassicMacM68k
{
    return [self _isM68k] && [_target isEqualToString:@"q800"];
}

- (BOOL)_isClassicMacNewWorld
{
    return [self _isPPC] && [_target isEqualToString:@"mac99"];
}

#pragma mark - Device Availability

- (NSString *)_qemuBinaryForArch:(NSString *)arch
{
    return [NSString stringWithFormat:@"qemu-system-%@", arch];
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
    return _networkCard ?: @"e1000";
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

- (NSString *)_findFile:(NSString *)name inDirectory:(NSString *)dir
{
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dir isDirectory:&isDir] || !isDir) return nil;
    NSString *candidate = [dir stringByAppendingPathComponent:name];
    if ([fm isReadableFileAtPath:candidate]) return candidate;
    NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:NULL];
    for (NSString *item in contents) {
        NSString *sub = [dir stringByAppendingPathComponent:item];
        if ([fm fileExistsAtPath:sub isDirectory:&isDir] && isDir) {
            NSString *found = [self _findFile:name inDirectory:sub];
            if (found) return found;
        }
    }
    return nil;
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
            path = [path lastPathComponent];
        }
        /* Search in bundle subdirectories for the file */
        for (NSString *sub in @[@"Data", @"Images", @""]) {
            NSString *searchDir = [[baseURL URLByAppendingPathComponent:sub isDirectory:YES] path];
            NSString *found = [self _findFile:path inDirectory:searchDir];
            if (found) { drive[@"ImagePath"] = found; break; }
        }
    }
}

- (NSString *)_uuidString
{
    id info = _rawPlist[@"Information"] ?: _rawPlist[@"Info"];
    if ([info isKindOfClass:[NSDictionary class]]) return [info objectForKey:@"UUID"];
    return nil;
}

- (NSString *)_machineProperties
{
    BOOL isPc = [self _isPcCompatible];
    BOOL isUsb = [self _hasUsbSupport];
    NSString *target = [self targetString];
    NSMutableString *props = [NSMutableString string];

    if (isPc) {
        [props appendString:@",vmport=off"];
        if (isUsb && !_inputLegacy) {
            [props appendString:@",i8042=off"];
        }
        [props appendString:@",hpet=off"];
    }

    if ([target isEqualToString:@"virt"] || [target hasPrefix:@"virt-"]) {
        if ([_architecture isEqualToString:@"aarch64"] && _cpuCount > 8) {
            [props appendString:@",gic-version=3"];
        }
    }

    if ([self _isClassicMacNewWorld]) {
        [props appendString:@",via=pmu"];
    }

    return props;
}

- (NSString *)_cleanupName:(NSString *)name
{
    NSCharacterSet *allowed = [NSCharacterSet alphanumericCharacterSet];
    NSMutableCharacterSet *mutable = [[allowed mutableCopy] autorelease];
    [mutable formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    return [[name componentsSeparatedByCharactersInSet:[mutable invertedSet]] componentsJoinedByString:@""];
}

- (NSArray<NSString *> *)qemuArguments
{
    NSMutableArray *args = [NSMutableArray array];
    NSString *uuid = [self _uuidString] ?: @"00000000-0000-0000-0000-000000000000";

    BOOL isSparc = [self _isSparc];
    BOOL isM68k = [self _isM68k];
    BOOL isS390x = [self _isS390x];
    BOOL isPcCompatible = [self _isPcCompatible];
    BOOL hasUsb = [self _hasUsbSupport];
    BOOL hasAgent = [self _hasAgentSupport];
    BOOL isClassicMacM68k = [self _isClassicMacM68k];
    BOOL isClassicMacNewWorld = [self _isClassicMacNewWorld];
    BOOL isUsbUsed = hasUsb && !_inputLegacy;

    id qemuSection = _rawPlist[@"QEMU"];
    BOOL wantsHostCPU = [_cpu isEqualToString:@"host"];
    BOOL hasUefi = NO;
    BOOL hasHypervisor = NO;
    BOOL hasRng = NO;
    BOOL hasBalloon = NO;
    BOOL hasRtcLocalTime = NO;
    BOOL isDisposable = NO;
    NSString *spicePassword = nil;
    NSArray *cpuFlagsAdd = nil;
    NSArray *cpuFlagsRemove = nil;
    if ([qemuSection isKindOfClass:[NSDictionary class]]) {
        hasHypervisor = [qemuSection[@"Hypervisor"] boolValue];
        hasUefi = [qemuSection[@"UEFIBoot"] boolValue];
        hasRng = [qemuSection[@"RNGDevice"] boolValue];
        hasBalloon = [qemuSection[@"BalloonDevice"] boolValue];
        hasRtcLocalTime = [qemuSection[@"HasRTCLocalTime"] boolValue];
        isDisposable = [qemuSection[@"Disposable"] boolValue];
        spicePassword = qemuSection[@"SpicePassword"];
        cpuFlagsAdd = qemuSection[@"CpuFlagsAdd"];
        cpuFlagsRemove = qemuSection[@"CpuFlagsRemove"];
        if (!wantsHostCPU && hasHypervisor) {
            wantsHostCPU = YES;
        }
    }

    id sharingSection = _rawPlist[@"Sharing"];
    BOOL clipboardSharing = NO;
    BOOL directorySharing = NO;
    if ([sharingSection isKindOfClass:[NSDictionary class]]) {
        clipboardSharing = [sharingSection[@"ClipboardSharing"] boolValue];
        directorySharing = [sharingSection[@"DirectorySharing"] boolValue];
    }

    id displayObj = _rawPlist[@"Display"];
    id serialArr = _rawPlist[@"Serial"];
    id netObj = _rawPlist[@"Networking"] ?: _rawPlist[@"Network"];
    id soundObj = _rawPlist[@"Sound"];
    id inputSection = _rawPlist[@"Input"];
    NSInteger maxUsbShare = 3;
    if ([inputSection isKindOfClass:[NSDictionary class]]) {
        maxUsbShare = [[inputSection objectForKey:@"MaximumUsbShare"] integerValue];
    }

    /* === 1. SPICE === */
    {
        NSMutableString *spiceArg = [NSMutableString stringWithFormat:@"unix=on,addr=%@.spice", uuid];
        if ([spicePassword length] > 0) {
            [spiceArg appendString:@",password-secret=secspice0"];
        } else {
            [spiceArg appendString:@",disable-ticketing=on"];
        }
        [spiceArg appendString:@",image-compression=off,playback-compression=off,streaming-video=off,gl=off"];
        [args addObject:@"-spice"];
        [args addObject:spiceArg];
    }

    /* === 2. QMP Monitor === */
    [args addObject:@"-chardev"];
    [args addObject:@"spiceport,name=org.qemu.monitor.qmp.0,id=org.qemu.monitor.qmp"];
    [args addObject:@"-mon"];
    [args addObject:@"chardev=org.qemu.monitor.qmp,mode=control"];

    /* === 3. -nodefaults: skip for SPARC (needs built-in devices) === */
    if (!isSparc) {
        [args addObject:@"-nodefaults"];
        [args addObject:@"-vga"];
        [args addObject:@"none"];
    }

    /* === 4. SPICE password object === */
    if ([spicePassword length] > 0) {
        [args addObject:@"-object"];
        [args addObject:[NSString stringWithFormat:@"secret,id=secspice0,data=%@", spicePassword]];
    }

    /* === 5. Display === */
    {
        BOOL hasDisplayDevice = NO;
        if (isSparc) {
            NSString *vgaCard = @"tcx";
            if ([displayObj isKindOfClass:[NSDictionary class]]) {
                NSString *hw = [displayObj objectForKey:@"DisplayCard"] ?: [displayObj objectForKey:@"Hardware"];
                if (hw) vgaCard = hw;
            }
            [args addObject:@"-vga"];
            [args addObject:vgaCard];
            hasDisplayDevice = YES;
        } else if ([displayObj isKindOfClass:[NSArray class]] && [displayObj count] > 0) {
            for (NSDictionary *d in displayObj) {
                if ([d isKindOfClass:[NSDictionary class]]) {
                    NSString *hw = [d objectForKey:@"Hardware"];
                    if (hw) {
                        hw = [self availableDeviceFor:hw arch:_architecture];
                        [args addObject:@"-device"];
                        [args addObject:hw];
                        hasDisplayDevice = YES;
                    }
                }
            }
        } else if ([displayObj isKindOfClass:[NSDictionary class]]) {
            NSString *hw = [displayObj objectForKey:@"Hardware"];
            if (hw) {
                hw = [self availableDeviceFor:hw arch:_architecture];
                [args addObject:@"-device"];
                [args addObject:hw];
                hasDisplayDevice = YES;
            }
        }
        if (!hasDisplayDevice) {
            [args addObject:@"-device"];
            [args addObject:[self availableDeviceFor:@"virtio-ramfb" arch:_architecture]];
        }
    }
    [args addObject:@"-display"];
    [args addObject:@"sdl"];

    /* === 6. Network (multi-card with indexing) === */
    {
        NSMutableArray *netConfigs = [NSMutableArray array];
        if ([netObj isKindOfClass:[NSArray class]]) {
            [netConfigs addObjectsFromArray:netObj];
        } else if ([netObj isKindOfClass:[NSDictionary class]]) {
            [netConfigs addObject:netObj];
        }

        if ([netConfigs count] == 0) {
            [args addObject:@"-nic"];
            [args addObject:@"none"];
        } else {
            for (NSUInteger i = 0; i < [netConfigs count]; i++) {
                NSDictionary *netDict = netConfigs[i];
                NSString *macAddr = netDict[@"NetworkCardMAC"] ?: netDict[@"MacAddress"] ?: @"";
                NSString *netMode = netDict[@"NetworkMode"] ?: netDict[@"Mode"] ?: @"shared";

                if (isSparc || (isClassicMacM68k && [netDict[@"Hardware"] isEqualToString:@"dp8393x"])) {
                    NSMutableString *netArg = [NSMutableString stringWithFormat:@"nic,netdev=net%lu", (unsigned long)i];
                    if (isSparc) {
                        [netArg appendString:@",model=lance"];
                    }
                    if ([macAddr length] > 0) {
                        [netArg appendFormat:@",macaddr=%@", macAddr];
                    }
                    [args addObject:@"-net"];
                    [args addObject:netArg];
                } else {
                    NSString *netHw = netDict[@"Hardware"] ?: _networkCard ?: @"rtl8139";
                    netHw = [self availableDeviceFor:netHw arch:_architecture];
                    NSMutableString *devArg = [NSMutableString stringWithFormat:@"%@,netdev=net%lu", netHw, (unsigned long)i];
                    if ([macAddr length] > 0) {
                        [devArg appendFormat:@",mac=%@", macAddr];
                    }
                    [args addObject:@"-device"];
                    [args addObject:devArg];
                }

                [args addObject:@"-netdev"];
                if ([netMode isEqualToString:@"shared"] || [netMode isEqualToString:@"emulated"]) {
                    NSMutableString *netdevArg = [NSMutableString stringWithFormat:@"user,id=net%lu", (unsigned long)i];
                    NSString *guestAddr = netDict[@"VlanGuestAddress"];
                    if (guestAddr) {
                        [netdevArg appendFormat:@",net=%@", guestAddr];
                    }
                    NSString *hostAddr = netDict[@"VlanHostAddress"];
                    if (hostAddr) {
                        [netdevArg appendFormat:@",host=%@", hostAddr];
                    }
                    NSArray *portForwards = netDict[@"PortForward"];
                    if ([portForwards isKindOfClass:[NSArray class]]) {
                        for (NSDictionary *pf in portForwards) {
                            NSString *proto = pf[@"Protocol"] ?: @"tcp";
                            NSString *ha = pf[@"HostAddress"] ?: @"";
                            NSString *hp = pf[@"HostPort"];
                            NSString *ga = pf[@"GuestAddress"] ?: @"";
                            NSString *gp = pf[@"GuestPort"];
                            if (hp && gp) {
                                [netdevArg appendFormat:@",hostfwd=%@:%@:%@-%@:%@",
                                 [proto lowercaseString], ha, hp, ga, gp];
                            }
                        }
                    }
                    if ([netDict[@"IsIsolateFromHost"] boolValue]) {
                        [netdevArg appendString:@",restrict=on"];
                    }
                    [args addObject:netdevArg];
                } else if ([netMode isEqualToString:@"bridged"]) {
                    NSString *iface = netDict[@"BridgeInterface"] ?: @"eth0";
                    [args addObject:[NSString stringWithFormat:@"bridge,id=net%lu,br=%@", (unsigned long)i, iface]];
                } else if ([netMode isEqualToString:@"host"]) {
                    [args addObject:[NSString stringWithFormat:@"user,id=net%lu,restrict=on", (unsigned long)i]];
                } else {
                    [args addObject:[NSString stringWithFormat:@"user,id=net%lu", (unsigned long)i]];
                }
            }
        }
    }

    /* === 7. Serial === */
    if ([serialArr isKindOfClass:[NSArray class]]) {
        for (NSUInteger i = 0; i < [serialArr count]; i++) {
            NSDictionary *ser = serialArr[i];
            if (![ser isKindOfClass:[NSDictionary class]]) continue;

            NSString *mode = ser[@"Mode"] ?: @"Builtin";
            NSString *target = ser[@"Target"] ?: @"Auto";

            [args addObject:@"-chardev"];
            if ([mode isEqualToString:@"TcpClient"]) {
                NSString *host = ser[@"TcpHostAddress"] ?: @"localhost";
                NSNumber *port = ser[@"TcpPort"] ?: @1234;
                [args addObject:[NSString stringWithFormat:@"socket,id=term%lu,host=%@,port=%@,server=off",
                                (unsigned long)i, host, port]];
            } else if ([mode isEqualToString:@"TcpServer"]) {
                NSString *bindAddr = [ser[@"IsRemoteConnectionAllowed"] boolValue] ? @"0.0.0.0" : @"127.0.0.1";
                NSNumber *port = ser[@"TcpPort"] ?: @1234;
                NSString *wait = [ser[@"IsWaitForConnection"] boolValue] ? @"on" : @"off";
                [args addObject:[NSString stringWithFormat:@"socket,id=term%lu,host=%@,port=%@,server=on,wait=%@",
                                (unsigned long)i, bindAddr, port, wait]];
            } else {
                [args addObject:[NSString stringWithFormat:@"spiceport,id=term%lu,name=com.utmapp.terminal.%lu",
                                (unsigned long)i, (unsigned long)i]];
            }

            if ([target isEqualToString:@"Auto"]) {
                [args addObject:@"-serial"];
                [args addObject:[NSString stringWithFormat:@"chardev:term%lu", (unsigned long)i]];
            } else if ([target isEqualToString:@"Manual"]) {
                NSString *hw = ser[@"Hardware"] ?: @"isa-serial";
                [args addObject:@"-device"];
                [args addObject:[NSString stringWithFormat:@"%@,chardev=term%lu", hw, (unsigned long)i]];
            } else if ([target isEqualToString:@"Monitor"]) {
                [args addObject:@"-mon"];
                [args addObject:[NSString stringWithFormat:@"chardev=term%lu,mode=readline", (unsigned long)i]];
            } else if ([target isEqualToString:@"GDB"]) {
                [args addObject:@"-gdb"];
                [args addObject:[NSString stringWithFormat:@"chardev:term%lu", (unsigned long)i]];
            }
        }
    }

    /* === 8. CPU + SMP === */
    {
        if (wantsHostCPU) {
            [args addObject:@"-cpu"];
            [args addObject:@"host"];
        } else if (![_cpu isEqualToString:@"default"]) {
            [args addObject:@"-cpu"];
            NSMutableString *cpuArg = [NSMutableString stringWithString:_cpu];
            for (NSString *flag in cpuFlagsAdd) {
                if ([flag length] > 0) {
                    [cpuArg appendFormat:@",+%@", flag];
                }
            }
            for (NSString *flag in cpuFlagsRemove) {
                if ([flag length] > 0) {
                    [cpuArg appendFormat:@",-%@", flag];
                }
            }
            [args addObject:cpuArg];
        } else if ([_architecture isEqualToString:@"aarch64"]) {
            [args addObject:@"-cpu"];
            [args addObject:@"cortex-a72"];
        } else if ([_architecture isEqualToString:@"arm"]) {
            [args addObject:@"-cpu"];
            [args addObject:@"cortex-a15"];
        }

        NSUInteger ncpu = isSparc ? 1 : (_cpuCount > 0 ? _cpuCount : 1);
        [args addObject:@"-smp"];
        [args addObject:[NSString stringWithFormat:@"cpus=%lu,sockets=1,cores=%lu,threads=1",
                         (unsigned long)ncpu, (unsigned long)ncpu]];
    }

    /* === 9. Machine + Acceleration + Boot === */
    {
        NSString *machineTarget = [self targetString];
        NSString *machineProps = [self _machineProperties];
        if ([machineProps length] > 0) {
            machineTarget = [machineTarget stringByAppendingString:machineProps];
        }
        [args addObject:@"-machine"];
        [args addObject:machineTarget];

        if (isSparc) {
            [args addObject:@"-prom-env"];
            [args addObject:@"boot-device=disk"];
        }
        if (isClassicMacNewWorld) {
            [args addObject:@"-prom-env"];
            [args addObject:@"boot-command=init-program go"];
        }

        if (hasHypervisor && [[NSFileManager defaultManager] isReadableFileAtPath:@"/dev/kvm"]) {
            [args addObject:@"-accel"];
            [args addObject:@"kvm"];
        } else {
            [args addObject:@"-accel"];
            [args addObject:@"tcg"];
        }
    }

    /* === 10. Architecture-specific === */
    if (isPcCompatible) {
        [args addObject:@"-global"];
        [args addObject:@"PIIX4_PM.disable_s3=1"];
        [args addObject:@"-global"];
        [args addObject:@"ICH9-LPC.disable_s3=1"];
    }

    if (hasUefi) {
        NSString *prefix = [_architecture isEqualToString:@"aarch64"] ? @"aarch64" : @"x86_64";
        NSString *codeFile = [NSString stringWithFormat:@"/usr/share/qemu/edk2-%@-code.fd", prefix];
        NSFileManager *fm = [NSFileManager defaultManager];
        if ([fm isReadableFileAtPath:codeFile]) {
            [args addObject:@"-drive"];
            [args addObject:[NSString stringWithFormat:@"if=pflash,format=raw,unit=0,file.filename=%@,file.locking=off,readonly=on", codeFile]];
        }
        NSString *varsFile = [NSTemporaryDirectory() stringByAppendingPathComponent:@"efi_vars.fd"];
        if (![fm fileExistsAtPath:varsFile]) {
            NSString *template = [NSString stringWithFormat:@"/usr/share/qemu/edk2-%@-vars.fd", prefix];
            if ([fm isReadableFileAtPath:template]) {
                [fm copyItemAtPath:template toPath:varsFile error:NULL];
            }
        }
        if ([fm isReadableFileAtPath:varsFile]) {
            [args addObject:@"-drive"];
            [args addObject:[NSString stringWithFormat:@"if=pflash,unit=1,file.filename=%@", varsFile]];
        }
    }

    if (isClassicMacM68k) {
        [args addObject:@"-device"];
        [args addObject:@"nubus-virtio-mmio"];
    }

    /* === 11. Memory === */
    [args addObject:@"-m"];
    [args addObject:[NSString stringWithFormat:@"%lu", (unsigned long)_memorySize]];

    /* === 12. Boot === */
    if ([_bootDevice isEqualToString:@"cd"]) {
        [args addObject:@"-boot"];
        [args addObject:@"once=d,order=c"];
    } else if ([_bootDevice isEqualToString:@"disk"]) {
        [args addObject:@"-boot"];
        [args addObject:@"order=c"];
    }

    /* === 13. Sound === */
    {
        NSString *soundHw = nil;
        if ([soundObj isKindOfClass:[NSArray class]] && [soundObj count] > 0) {
            id first = [soundObj objectAtIndex:0];
            if ([first isKindOfClass:[NSDictionary class]]) soundHw = [first objectForKey:@"Hardware"];
        } else if ([soundObj isKindOfClass:[NSDictionary class]]) {
            soundHw = [soundObj objectForKey:@"Hardware"] ?: [soundObj objectForKey:@"SoundCard"];
        }
            if (soundHw || _soundEnabled) {
            if (!soundHw) soundHw = _soundCard;
            if ([soundHw isEqualToString:@"hda"]) soundHw = @"intel-hda";
            soundHw = [self availableDeviceFor:soundHw arch:_architecture];
            if (soundHw && [soundHw length] > 0) {
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
        }
    }

    /* === 14. USB (skip for SPARC/m68k/s390x / legacy input) === */
    if (isUsbUsed) {
        NSString *usbCtrl = [self availableDeviceFor:@"nec-usb-xhci" arch:_architecture];
        if ([_target isEqualToString:@"virt"] || [_architecture isEqualToString:@"aarch64"]) {
            [args addObject:@"-device"];
            [args addObject:[NSString stringWithFormat:@"%@,id=usb-bus", usbCtrl]];
        } else {
            [args addObject:@"-usb"];
        }

        if (!isClassicMacNewWorld) {
            [args addObject:@"-device"];
            [args addObject:@"usb-tablet,bus=usb-bus.0"];
        }
            [args addObject:@"-device"];
            [args addObject:@"usb-mouse,bus=usb-bus.0"];
            [args addObject:@"-device"];
            [args addObject:@"usb-kbd,bus=usb-bus.0"];

        if (maxUsbShare > 0) {
            [args addObject:@"-device"];
            [args addObject:@"qemu-xhci,id=usb-controller-0"];
            for (int i = 0; i < maxUsbShare && i < 3; i++) {
                [args addObject:@"-chardev"];
                [args addObject:[NSString stringWithFormat:@"spicevmc,name=usbredir,id=usbredirchardev%d", i]];
                [args addObject:@"-device"];
                [args addObject:[NSString stringWithFormat:@"usb-redir,chardev=usbredirchardev%d,id=usbredirdev%d,bus=usb-controller-0.0", i, i]];
            }
        }
    }

    /* === 15. Other Inputs (classic mac) === */
    if (isClassicMacNewWorld) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-tablet-pci"];
    }
    if (isClassicMacM68k) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-tablet-device"];
    }

    /* === 16. Drives === */
    {
        int bootIdx = 0;
        for (NSDictionary *drive in _drives) {
            NSString *imagePath = drive[@"ImagePath"] ?: drive[@"ImageName"];
            NSString *imageType = drive[@"ImageType"] ?: @"disk";
            NSString *interface = drive[@"InterfaceType"] ?: drive[@"Interface"] ?: @"ide";
            NSString *identifier = drive[@"Identifier"];
            BOOL isCd = [imageType caseInsensitiveCompare:@"cd"] == NSOrderedSame;
            BOOL isDisk = [imageType caseInsensitiveCompare:@"disk"] == NSOrderedSame;
            BOOL isBios = [imageType caseInsensitiveCompare:@"bios"] == NSOrderedSame;
            BOOL isKernel = [imageType caseInsensitiveCompare:@"LinuxKernel"] == NSOrderedSame;
            BOOL isInitrd = [imageType caseInsensitiveCompare:@"LinuxInitrd"] == NSOrderedSame;
            BOOL isDtb = [imageType caseInsensitiveCompare:@"LinuxDTB"] == NSOrderedSame;
            BOOL removable = [drive[@"Removable"] boolValue];
            BOOL readOnly = [drive[@"ReadOnly"] boolValue];

            if (isBios && imagePath) {
                [args addObject:@"-bios"];
                [args addObject:imagePath];
                continue;
            }
            if (isKernel && imagePath) {
                [args addObject:@"-kernel"];
                [args addObject:imagePath];
                continue;
            }
            if (isInitrd && imagePath) {
                [args addObject:@"-initrd"];
                [args addObject:imagePath];
                continue;
            }
            if (isDtb && imagePath) {
                [args addObject:@"-dtb"];
                [args addObject:imagePath];
                continue;
            }

            if (!isDisk && !isCd) continue;

            NSString *driveId = identifier ? [NSString stringWithFormat:@"drive%@", identifier] :
                                             [NSString stringWithFormat:@"drive%d", bootIdx];
            BOOL actuallyRemovable = removable || (isCd && !imagePath);
            if (!imagePath && !actuallyRemovable) continue;

            NSString *iface = [interface lowercaseString];

            /* ---- IDE ---- */
            if ([iface isEqualToString:@"ide"]) {
                NSString *devName = isCd ? @"ide-cd" : @"ide-hd";
                NSMutableString *devArg = [NSMutableString stringWithFormat:@"%@,drive=%@", devName, driveId];
                if (isPcCompatible) {
                    [devArg appendFormat:@",bus=ide.%d", bootIdx];
                }
                [devArg appendFormat:@",bootindex=%d", bootIdx];
                [args addObject:@"-device"];
                [args addObject:devArg];

                NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=none,media=%@,id=%@",
                                              isCd ? @"cdrom" : @"disk", driveId];
                if (imagePath)
                    [driveArg appendFormat:@",file.filename=%@", imagePath];
                else if (isCd || actuallyRemovable)
                    [driveArg appendString:@",file.filename=/dev/null"];
                if (isCd || actuallyRemovable || readOnly)
                    [driveArg appendString:@",file.locking=off,readonly=on"];
                if (isDisk)
                    [driveArg appendString:@",discard=unmap,detect-zeroes=unmap"];
                [args addObject:@"-drive"];
                [args addObject:driveArg];
                bootIdx++;

            /* ---- SCSI ---- */
            } else if ([iface isEqualToString:@"scsi"]) {
                BOOL hasBuiltinScsi = isSparc || isM68k;
                if (!hasBuiltinScsi) {
                    [args addObject:@"-device"];
                    [args addObject:@"lsi53c895a,id=scsi0"];
                }
                NSString *busName = hasBuiltinScsi ? @"scsi" : @"scsi0";
                NSString *devName = isCd ? @"scsi-cd" : @"scsi-hd";
                NSMutableString *devArg = [NSMutableString stringWithFormat:@"%@,bus=%@.0,channel=0,scsi-id=%d,drive=%@",
                                            devName, busName, bootIdx, driveId];
                if (!isSparc) {
                    [devArg appendFormat:@",bootindex=%d", bootIdx];
                }
                [args addObject:@"-device"];
                [args addObject:devArg];

                NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=none,media=%@,id=%@",
                                              isCd ? @"cdrom" : @"disk", driveId];
                if (imagePath)
                    [driveArg appendFormat:@",file.filename=%@", imagePath];
                else if (isCd || actuallyRemovable)
                    [driveArg appendString:@",file.filename=/dev/null"];
                if (isCd || actuallyRemovable || readOnly)
                    [driveArg appendString:@",file.locking=off,readonly=on"];
                if (isDisk)
                    [driveArg appendString:@",discard=unmap,detect-zeroes=unmap"];
                [args addObject:@"-drive"];
                [args addObject:driveArg];
                bootIdx++;

            /* ---- VirtIO ---- */
            } else if ([iface isEqualToString:@"virtio"]) {
                NSString *virtioDev;
                if (isS390x)
                    virtioDev = @"virtio-blk-ccw";
                else if (isM68k)
                    virtioDev = @"virtio-blk-device";
                else
                    virtioDev = @"virtio-blk-pci";
                NSMutableString *devArg = [NSMutableString stringWithFormat:@"%@,drive=%@", virtioDev, driveId];
                if (identifier && [identifier length] > 0) {
                    NSString *serial = [[identifier stringByReplacingOccurrencesOfString:@"-" withString:@""] substringToIndex:20];
                    [devArg appendFormat:@",serial=%@", serial];
                }
                [devArg appendFormat:@",bootindex=%d", bootIdx];
                [args addObject:@"-device"];
                [args addObject:devArg];

                NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=none,media=%@,id=%@",
                                              isCd ? @"cdrom" : @"disk", driveId];
                if (imagePath)
                    [driveArg appendFormat:@",file.filename=%@", imagePath];
                else if (isCd || actuallyRemovable)
                    [driveArg appendString:@",file.filename=/dev/null"];
                if (isCd || actuallyRemovable || readOnly)
                    [driveArg appendString:@",file.locking=off,readonly=on"];
                if (isDisk)
                    [driveArg appendString:@",discard=unmap,detect-zeroes=unmap"];
                [args addObject:@"-drive"];
                [args addObject:driveArg];
                bootIdx++;

            /* ---- NVMe ---- */
            } else if ([iface isEqualToString:@"nvme"]) {
                NSMutableString *devArg = [NSMutableString stringWithFormat:@"nvme,drive=%@,serial=%@",
                                            driveId, driveId];
                [devArg appendFormat:@",bootindex=%d", bootIdx];
                [args addObject:@"-device"];
                [args addObject:devArg];

                NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=none,media=%@,id=%@",
                                              isCd ? @"cdrom" : @"disk", driveId];
                if (imagePath)
                    [driveArg appendFormat:@",file.filename=%@", imagePath];
                else if (isCd || actuallyRemovable)
                    [driveArg appendString:@",file.filename=/dev/null"];
                if (isCd || actuallyRemovable || readOnly)
                    [driveArg appendString:@",file.locking=off,readonly=on"];
                if (isDisk)
                    [driveArg appendString:@",discard=unmap,detect-zeroes=unmap"];
                [args addObject:@"-drive"];
                [args addObject:driveArg];
                bootIdx++;

            /* ---- USB ---- */
            } else if ([iface isEqualToString:@"usb"]) {
                NSMutableString *devArg = [NSMutableString stringWithFormat:@"usb-storage,drive=%@,removable=%s",
                                            driveId, actuallyRemovable ? "true" : "false"];
                if (hasUsb && [_target hasPrefix:@"virt"])
                    [devArg appendString:@",bus=usb-bus.0"];
                [devArg appendFormat:@",bootindex=%d", bootIdx];
                [args addObject:@"-device"];
                [args addObject:devArg];

                NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=none,media=%@,id=%@",
                                              isCd ? @"cdrom" : @"disk", driveId];
                if (imagePath)
                    [driveArg appendFormat:@",file.filename=%@", imagePath];
                else if (isCd || actuallyRemovable)
                    [driveArg appendString:@",file.filename=/dev/null"];
                if (isCd || actuallyRemovable || readOnly)
                    [driveArg appendString:@",file.locking=off,readonly=on"];
                if (isDisk)
                    [driveArg appendString:@",discard=unmap,detect-zeroes=unmap"];
                [args addObject:@"-drive"];
                [args addObject:driveArg];
                bootIdx++;

            /* ---- Floppy ---- */
            } else if ([iface isEqualToString:@"floppy"] && [self _isPcCompatible]) {
                [args addObject:@"-device"];
                [args addObject:[NSString stringWithFormat:@"isa-fdc,id=fdc%d", bootIdx]];
                [args addObject:@"-device"];
                [args addObject:[NSString stringWithFormat:@"floppy,unit=0,bus=fdc%d.0,drive=%@", bootIdx, driveId]];

                NSMutableString *driveArg = [NSMutableString stringWithFormat:@"if=floppy,id=%@", driveId];
                if (imagePath)
                    [driveArg appendFormat:@",file.filename=%@", imagePath];
                [args addObject:@"-drive"];
                [args addObject:driveArg];
                bootIdx++;
            }
        }
    }

    /* === 17. Sharing (virtio-serial + agents) === */
    if (hasAgent) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-serial"];

        if (clipboardSharing) {
            [args addObject:@"-device"];
            [args addObject:@"virtserialport,bus=virtio-serial-bus.0,chardev=org.qemu.guest_agent,name=org.qemu.guest_agent.0"];
            [args addObject:@"-chardev"];
            [args addObject:@"spiceport,name=org.qemu.guest_agent.0,id=org.qemu.guest_agent"];
        }

        if (clipboardSharing || directorySharing) {
            [args addObject:@"-device"];
            [args addObject:@"virtserialport,bus=virtio-serial-bus.0,chardev=vdagent,name=com.redhat.spice.0"];
            [args addObject:@"-chardev"];
            [args addObject:@"spicevmc,id=vdagent,debug=0,name=vdagent"];

            if (directorySharing) {
                [args addObject:@"-device"];
                [args addObject:@"virtserialport,bus=virtio-serial-bus.0,chardev=charchannel1,id=channel1,name=org.spice-space.webdav.0"];
                [args addObject:@"-chardev"];
                [args addObject:@"spiceport,name=org.spice-space.webdav.0,id=charchannel1"];
            }
        }
    }

    /* === 17. Name and UUID === */
    [args addObject:@"-name"];
    [args addObject:[self _cleanupName:_name ?: @"Virtual Machine"]];
    if (isDisposable) {
        [args addObject:@"-snapshot"];
    }
    [args addObject:@"-uuid"];
    [args addObject:uuid];

    /* === 18. RTC === */
    if (hasRtcLocalTime) {
        [args addObject:@"-rtc"];
        [args addObject:@"base=localtime"];
    }

    /* === 19. RNG + Balloon === */
    if (hasRng) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-rng-pci"];
    }
    if (hasBalloon) {
        [args addObject:@"-device"];
        [args addObject:@"virtio-balloon-pci"];
    }

    /* === 20. Extra arguments === */
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
