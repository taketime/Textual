// Created by Codeux Software <support AT codeux DOT com> <https://github.com/codeux/Textual>
// You can redistribute it and/or modify it under the new BSD license.

#import <Cocoa/Cocoa.h>

@interface DockIcon : NSObject

+ (void)drawWithoutCounts;
+ (NSString*)badgeFilename:(NSInteger)count;
+ (void)drawWithHilightCount:(NSInteger)hilight_count messageCount:(NSInteger)message_count;

@end