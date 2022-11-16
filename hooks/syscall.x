#import <substrate.h>
#import "hooks.h"

static int (*original_syscall)(int number, ...);
static int replaced_syscall(int number, ...) {
    HBLogDebug(@"%@: %d", @"syscall", number);

    char* stack[8];
	va_list args;
	va_start(args, number);

    #if defined __arm64__ || defined __arm64e__
	memcpy(stack, args, 64);
    #endif

    #if defined __armv7__ || defined __armv7s__
	memcpy(stack, args, 32);
    #endif

    // Handle single pathname syscalls
    if(number == SYS_open
    || number == SYS_chdir
    || number == SYS_access
    || number == SYS_execve
    || number == SYS_chroot
    || number == SYS_rmdir
    || number == SYS_stat
    || number == SYS_lstat
    || number == SYS_getattrlist
    || number == SYS_open_extended
    || number == SYS_stat_extended
    || number == SYS_lstat_extended
    || number == SYS_access_extended
    || number == SYS_stat64
    || number == SYS_lstat64
    || number == SYS_stat64_extended
    || number == SYS_lstat64_extended
    || number == SYS_readlink) {
        const char* pathname = va_arg(args, const char *);

        if([_shadow isCPathRestricted:pathname] && ![_shadow isCallerTweak:[NSThread callStackReturnAddresses]]) {
            errno = ENOENT;
            return -1;
        }
    }

    // Handle ptrace (anti debug)
    if(number == SYS_ptrace) {
        int _request = va_arg(args, int);

        if(_request == PT_DENY_ATTACH) {
            return 0;
        }
    }

    va_end(args);
    return original_syscall(number, stack[0], stack[1], stack[2], stack[3], stack[4], stack[5], stack[6], stack[7]);
}

// todo: research on "supervised syscalls"

void shadowhook_syscall(void) {
    MSHookFunction(syscall, replaced_syscall, (void **) &original_syscall);
}