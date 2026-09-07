#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BILObjCExceptionBlock)(void);

/// Runs a native operation that may raise an Objective-C exception.
///
/// Swift can catch Swift `Error` values, but it cannot catch Objective-C
/// exceptions raised by framework assertions. Native capture APIs such as
/// AVAudioEngine use those assertions for invalid hardware routes, so the
/// bridge needs a small Objective-C boundary to turn them into recoverable
/// failures instead of terminating Runner.
FOUNDATION_EXPORT BOOL BILPerformObjCExceptionCatching(
    BILObjCExceptionBlock block);

NS_ASSUME_NONNULL_END
