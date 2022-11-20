#import "SHDWAboutListController.h"

@implementation SHDWAboutListController {
	NSString* packageVersion;
	NSString* latestVersion;
	NSDictionary* versions;
}

- (NSArray *)specifiers {
	if(!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"About" target:self];
	}

	return _specifiers;
}

- (NSString *)aboutBypassVersion:(id)sender {
	return versions[@"bypass_version"];
}

- (NSString *)aboutAPIVersion:(id)sender {
	return versions[@"api_version"];
}

- (NSString *)aboutBuildDate:(id)sender {
	return versions[@"build_date"];
}

- (NSString *)aboutSoftwareLicense:(id)sender {
	return @"BSD 3-Clause";
}

- (NSString *)aboutDeveloper:(id)sender {
	return @"jjolano";
}

- (NSString *)aboutPackageVersion:(id)sender {
	if(packageVersion) {
		return packageVersion;
	}

	NSString* dpkgPath = nil;
	NSArray* dpkgPaths = @[
        @"/usr/bin/dpkg-query",
        @"/var/jb/usr/bin/dpkg-query",
        @"/usr/local/bin/dpkg-query",
        @"/var/jb/usr/local/bin/dpkg-query"
    ];

    for(NSString* path in dpkgPaths) {
        if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            dpkgPath = path;
            break;
        }
    }
	
	if(!dpkgPath) {
		return @"unknown";
	}

	NSTask* task = [NSTask new];
	NSPipe* stdoutPipe = [NSPipe new];

	[task setLaunchPath:dpkgPath];
	[task setArguments:@[@"-W", @"me.jjolano.shadow"]];
	[task setStandardOutput:stdoutPipe];
	[task launch];
	[task waitUntilExit];

	if([task terminationStatus] == 0) {
		NSData* data = [[stdoutPipe fileHandleForReading] readDataToEndOfFile];
		NSString* output = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];

		NSCharacterSet* separator = [NSCharacterSet newlineCharacterSet];
		NSArray<NSString *>* lines = [output componentsSeparatedByCharactersInSet:separator];

		for(NSString* entry in lines) {
			NSArray<NSString *>* line = [entry componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			packageVersion = [line lastObject];
			break;
		}
	} else {
		packageVersion = @"unknown";
	}

	return packageVersion;
}

- (NSString *)aboutLatestVersion:(id)sender {
	if(latestVersion) {
		return latestVersion;
	}

	NSURLRequest* request = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:@"https://api.github.com/repos/jjolano/shadow/releases/latest"]];

	__block NSDictionary* json;
	[NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
		if(!connectionError) {
			json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
			latestVersion = [json[@"tag_name"] substringFromIndex:1];
		} else {
			latestVersion = @"unknown";
		}

		[self reloadSpecifier:sender];
	}];

	return latestVersion;
}

- (instancetype)init {
	if((self = [super init])) {
		ShadowService* service = [ShadowService new];

		packageVersion = nil;
		latestVersion = nil;

		versions = [service getVersions];
	}

	return self;
}
@end