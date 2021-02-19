// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCrashlyticsReport_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

@interface FIRCrashlyticsReportTests : XCTestCase

@end

@implementation FIRCrashlyticsReportTests

- (void)setUp {
  [super setUp];

  FIRCLSContextBaseInit();

  // these values must be set for the internals of logging to work
  _firclsContext.readonly->logging.userKVStorage.maxCount = 16;
  _firclsContext.readonly->logging.userKVStorage.maxIncrementalCount = 16;
  _firclsContext.readonly->logging.internalKVStorage.maxCount = 32;
  _firclsContext.readonly->logging.internalKVStorage.maxIncrementalCount = 16;

  _firclsContext.readonly->initialized = true;
}

- (void)tearDown {
  FIRCLSContextBaseDeinit();

  [super tearDown];
}

- (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSString *)pathForResource:(NSString *)name {
  return [[self resourcePath] stringByAppendingPathComponent:name];
}

- (FIRCLSInternalReport *)createTempCopyOfInternalReportWithName:(NSString *)name {
  NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:name];

  // make sure to remove anything that was there previously
  [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

  NSString *resourcePath = [self pathForResource:name];

  [[NSFileManager defaultManager] copyItemAtPath:resourcePath toPath:tempPath error:nil];

  return [[FIRCLSInternalReport alloc] initWithPath:tempPath];
}

- (FIRCrashlyticsReport *)createTempCopyOfReportWithName:(NSString *)name {
  FIRCLSInternalReport *internalReport = [self createTempCopyOfInternalReportWithName:name];
  if (!internalReport) {
    XCTAssertTrue(false);
  }

  return [[FIRCrashlyticsReport alloc] initWithInternalReport:internalReport];
}

#pragma mark - Public Getter Methods
- (void)testPropertiesFromMetadatFile {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  XCTAssertEqualObjects(@"772929a7f21f4ad293bb644668f257cd", report.reportID);
  XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:1423944888], report.dateCreated);
}

#pragma mark - Public Setter Methods
- (void)testSetUserID {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report setUserID:@"12345-6"];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportInternalIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 1, @"");

  XCTAssertEqualObjects(entries[0][@"kv"][@"key"],
                        FIRCLSFileHexEncodeString([FIRCLSUserIdentifierKey UTF8String]), @"");
  XCTAssertEqualObjects(entries[0][@"kv"][@"value"], FIRCLSFileHexEncodeString("12345-6"), @"");
}

- (void)testCustomKeysWhenNoneWerePresent {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report setCustomValue:@"hello" forKey:@"mykey"];
  [report setCustomValue:@"goodbye" forKey:@"anotherkey"];

  [report setCustomKeysAndValues:@{
    @"is_test" : @(YES),
    @"test_number" : @(10),
  }];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 4, @"");

  // mykey = "..."
  XCTAssertEqualObjects(entries[0][@"kv"][@"key"], FIRCLSFileHexEncodeString("mykey"), @"");
  XCTAssertEqualObjects(entries[0][@"kv"][@"value"], FIRCLSFileHexEncodeString("hello"), @"");

  // anotherkey = "..."
  XCTAssertEqualObjects(entries[1][@"kv"][@"key"], FIRCLSFileHexEncodeString("anotherkey"), @"");
  XCTAssertEqualObjects(entries[1][@"kv"][@"value"], FIRCLSFileHexEncodeString("goodbye"), @"");

  XCTAssertEqualObjects(entries[2][@"kv"][@"key"], FIRCLSFileHexEncodeString("is_test"), @"");
  XCTAssertEqualObjects(entries[2][@"kv"][@"value"], FIRCLSFileHexEncodeString("1"), @"");

  XCTAssertEqualObjects(entries[3][@"kv"][@"key"], FIRCLSFileHexEncodeString("test_number"), @"");
  XCTAssertEqualObjects(entries[3][@"kv"][@"value"], FIRCLSFileHexEncodeString("10"), @"");
}

@end
