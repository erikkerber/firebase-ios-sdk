//
//  FIRCrashlyticsReport.m
//  Pods
//
//  Created by Sam Edson on 12/14/20.
//

#import "FIRCrashlyticsReport.h"

#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

@interface FIRCrashlyticsReport () {
  NSString *_reportID;
  NSDate *_dateCreated;
  BOOL _hasCrash;
}

@end

@implementation FIRCrashlyticsReport

- (instancetype)initWithInternalReport:(FIRCLSInternalReport *)internalReport {
  self = [super init];
  if (!self) {
    return nil;
  }

  _reportID = [[internalReport identifier] copy];
  _dateCreated = [[internalReport dateCreated] copy];
  _hasCrash = [internalReport isCrash];

  return self;
}

- (NSString *)reportID {
  return _reportID;
}

- (NSDate *)dateCreated {
  return _dateCreated;
}

- (BOOL)hasCrash {
  return _hasCrash;
}

#pragma mark - API: Logging

- (void)log:(NSString *)msg {
  // TODO
  // TODO
  // TODO
  // TODO
  // TODO
  // TODO
  // TODO
  // TODO
  //
  // Need to:
  //   Check that send/delete have been called, and error log
  //   Make sure we don't move the report before calling send/delete
  //
  //
}

- (void)logWithFormat:(NSString *)format, ... {
  //  va_list args;
  //  va_start(args, format);
  //  [self logWithFormat:format arguments:args];
  //  va_end(args);
}

- (void)logWithFormat:(NSString *)format arguments:(va_list)args {
  //  [self log:[[NSString alloc] initWithFormat:format arguments:args]];
}

#pragma mark - API: setUserID

- (void)setUserID:(NSString *)userID {
  //  FIRCLSUserLoggingRecordInternalKeyValue(FIRCLSUserIdentifierKey, userID);
}

#pragma mark - API: setCustomValue

- (void)setCustomValue:(id)value forKey:(NSString *)key {
  //  FIRCLSUserLoggingRecordUserKeyValue(key, value);
}

- (void)setCustomKeysAndValues:(NSDictionary *)keysAndValues {
  //  FIRCLSUserLoggingRecordUserKeysAndValues(keysAndValues);
}

@end
