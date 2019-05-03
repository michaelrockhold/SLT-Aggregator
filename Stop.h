//
//  Stop.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class DepartureTime;
@class Timepoint;
@class Timetable;

@interface Stop :  NSManagedObject  
{
}

@property (nonatomic, retain) NSNumber * index;
@property (nonatomic, retain) NSString * info;
@property (nonatomic, retain) NSSet* departureTimes;
@property (nonatomic, retain) Timepoint * timepoint;
@property (nonatomic, retain) Timetable * timetable;

@end


@interface Stop (CoreDataGeneratedAccessors)
- (void)addDepartureTimesObject:(DepartureTime *)value;
- (void)removeDepartureTimesObject:(DepartureTime *)value;
- (void)addDepartureTimes:(NSSet *)value;
- (void)removeDepartureTimes:(NSSet *)value;

@end

