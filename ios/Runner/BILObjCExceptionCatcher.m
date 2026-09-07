#import "BILObjCExceptionCatcher.h"

BOOL BILPerformObjCExceptionCatching(BILObjCExceptionBlock block) {
  @try {
    block();
    return YES;
  } @catch (NSException *exception) {
    NSLog(@"[BIL] Recoverable native exception: %@", exception.reason ?: exception.name);
    return NO;
  }
}
