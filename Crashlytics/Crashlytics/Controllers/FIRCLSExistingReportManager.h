// Copyright 2021 Google LLC
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

NS_ASSUME_NONNULL_BEGIN

@class FIRCLSManagerData;
@class FIRCLSReportUploader;
@class FIRCLSDataCollectionToken;
@class FIRCrashlyticsReport;

@interface FIRCLSExistingReportManager : NSObject

/**
 * Returns the number of unsent reports on the device, ignoring reports in
 * the active folder that have needsToBeSubmitted == false.
 */
@property(nonatomic, readonly) NSUInteger numUnsentReports;
@property(nonatomic, readonly) FIRCrashlyticsReport *newestUnsentReport;

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
                     reportUploader:(FIRCLSReportUploader *)reportUploader;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (void)deleteUnsentReports;

- (void)sendUnsentReportsWithToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent;

@end

NS_ASSUME_NONNULL_END
