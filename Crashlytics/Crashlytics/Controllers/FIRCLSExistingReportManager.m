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

#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"

#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSReportUploader.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionToken.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSLogger.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCrashlyticsReport_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

@interface FIRCLSExistingReportManager ()

@property(nonatomic, strong) FIRCLSFileManager *fileManager;
@property(nonatomic, strong) NSOperationQueue *operationQueue;
@property(nonatomic, strong) FIRCLSReportUploader *reportUploader;

// This excludes the new active report that is created this run of the app.
@property(nonatomic, strong) NSArray *existingUnemptyActiveReportPaths;
@property(nonatomic, strong) NSArray *processingReportPaths;
@property(nonatomic, strong) NSArray *preparedReportPaths;

@end

@implementation FIRCLSExistingReportManager

- (instancetype)initWithManagerData:(FIRCLSManagerData *)managerData
                     reportUploader:(FIRCLSReportUploader *)reportUploader {
  self = [super init];
  if (!self) {
    return nil;
  }

  _fileManager = managerData.fileManager;
  _operationQueue = managerData.operationQueue;
  _reportUploader = reportUploader;

  // This is important to grab once early in startup because after this
  // has executed the new crash report for this session will be created
  // and start to reflect in activePathContents.
  _existingUnemptyActiveReportPaths =
      [self getUnemptyExistingActiveReportsAndDeleteEmpty:self.fileManager.activePathContents];
  _processingReportPaths = self.fileManager.processingPathContents;
  _preparedReportPaths = self.fileManager.preparedPathContents;

  return self;
}

NSInteger compareNewer(FIRCLSInternalReport *reportA,
                       FIRCLSInternalReport *reportB,
                       void *context) {
  return [reportA.dateCreated compare:reportB.dateCreated];
}

- (FIRCLSInternalReport *_Nullable)getNewestUnsentInternalReport {
  NSMutableArray<NSString *> *allReportPaths =
      [NSMutableArray arrayWithArray:self.existingUnemptyActiveReportPaths];
  [allReportPaths addObjectsFromArray:self.processingReportPaths];
  [allReportPaths addObjectsFromArray:self.preparedReportPaths];

  NSMutableArray<FIRCLSInternalReport *> *allReports = [NSMutableArray array];
  for (NSString *path in allReportPaths) {
    [allReports addObject:[FIRCLSInternalReport reportWithPath:path]];
  }

  [allReports sortUsingFunction:compareNewer context:nil];

  return [allReports lastObject];
}

- (FIRCrashlyticsReport *)newestUnsentReport {
  FIRCLSInternalReport *_Nullable internalReport = [self getNewestUnsentInternalReport];
  return [[FIRCrashlyticsReport alloc] initWithInternalReport:internalReport];
}

- (NSUInteger)numUnsentReports {
  NSUInteger count = self.existingUnemptyActiveReportPaths.count;
  count += self.processingReportPaths.count;
  count += self.preparedReportPaths.count;
  return count;
}

- (NSArray *)getUnemptyExistingActiveReportsAndDeleteEmpty:(NSArray *)reportPaths {
  NSMutableArray *unemptyReports = [NSMutableArray array];
  for (NSString *path in reportPaths) {
    FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
    if ([report hasAnyEvents]) {
      [unemptyReports addObject:path];
    } else {
      [self.operationQueue addOperationWithBlock:^{
        [self->_fileManager removeItemAtPath:path];
      }];
    }
  }
  return unemptyReports;
}

- (void)sendUnsentReportsWithToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                          asUrgent:(BOOL)urgent {
  for (NSString *path in self.existingUnemptyActiveReportPaths) {
    [self processExistingActiveReportPath:path
                      dataCollectionToken:dataCollectionToken
                                 asUrgent:urgent];
  }

  // deal with stuff in processing more carefully - do not process again
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in self.processingReportPaths) {
      FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];
      [self.reportUploader prepareAndSubmitReport:report
                              dataCollectionToken:dataCollectionToken
                                         asUrgent:NO
                                   withProcessing:NO];
    }
  }];

  // Because this could happen quite a bit after the inital set of files was
  // captured, some could be completed (deleted). So, just double-check to make sure
  // the file still exists.
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in self.preparedReportPaths) {
      if (![[self.fileManager underlyingFileManager] fileExistsAtPath:path]) {
        continue;
      }
      [self.reportUploader uploadPackagedReportAtPath:path
                                  dataCollectionToken:dataCollectionToken
                                             asUrgent:NO];
    }
  }];
}

- (void)processExistingActiveReportPath:(NSString *)path
                    dataCollectionToken:(FIRCLSDataCollectionToken *)dataCollectionToken
                               asUrgent:(BOOL)urgent {
  FIRCLSInternalReport *report = [FIRCLSInternalReport reportWithPath:path];

  // TODO: needsToBeSubmitted should really be called on the background queue.
  if (![report hasAnyEvents]) {
    [self.operationQueue addOperationWithBlock:^{
      [self->_fileManager removeItemAtPath:path];
    }];

    return;
  }

  if (urgent && [dataCollectionToken isValid]) {
    // We can proceed without the delegate.
    [self.reportUploader prepareAndSubmitReport:report
                            dataCollectionToken:dataCollectionToken
                                       asUrgent:urgent
                                 withProcessing:YES];
    return;
  }

  [self.operationQueue addOperationWithBlock:^{
    [self.reportUploader prepareAndSubmitReport:report
                            dataCollectionToken:dataCollectionToken
                                       asUrgent:NO
                                 withProcessing:YES];
  }];
}

// This is the side-effect of calling deleteUnsentReports, or collect_reports setting
// being false
- (void)deleteUnsentReports {
  [self removeExistingReportPaths:self.existingUnemptyActiveReportPaths];
  [self removeExistingReportPaths:self.fileManager.processingPathContents];
  [self removeExistingReportPaths:self.fileManager.preparedPathContents];
}

- (void)removeExistingReportPaths:(NSArray *)reportPaths {
  [self.operationQueue addOperationWithBlock:^{
    for (NSString *path in reportPaths) {
      [self.fileManager removeItemAtPath:path];
    }
  }];
}

@end
