//
//  Timetable.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Route;
@class Run;
@class Stop;

@interface Timetable :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSDate * expirationDate;
@property (nonatomic, retain) NSNumber * dayCode;
@property (nonatomic, retain) NSSet* stops;
@property (nonatomic, retain) NSSet* runs;
@property (nonatomic, retain) Route * route;

@end


@interface Timetable (CoreDataGeneratedAccessors)
- (void)addStopsObject:(Stop *)value;
- (void)removeStopsObject:(Stop *)value;
- (void)addStops:(NSSet *)value;
- (void)removeStops:(NSSet *)value;

- (void)addRunsObject:(Run *)value;
- (void)removeRunsObject:(Run *)value;
- (void)addRuns:(NSSet *)value;
- (void)removeRuns:(NSSet *)value;

@end

