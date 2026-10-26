#import "BILObjCExceptionCatcher.h"

BOOL BILPerformObjCExceptionCatching(BILObjCExceptionBlock block) {
  @try {
    block();
    return YES;
  } @catch (__unused NSException *exception) {
    // Audio route exceptions may embed device names or runtime arguments.
    // The caller already returns a reviewed, stable audio failure code.
    NSLog(@"[BIL] Recoverable native audio exception.");
    return NO;
  }
}
