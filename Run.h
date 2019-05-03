//
//  Run.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class DepartureTime;
@class Timetable;

@interface Run :  NSManagedObject  
{
}

@property (nonatomic, retain) NSNumber * index;
@property (nonatomic, retain) NSSet* departureTimes;
@property (nonatomic, retain) Timetable * timetable;

@end


@interface Run (CoreDataGeneratedAccessors)
- (void)addDepartureTimesObject:(DepartureTime *)value;
- (void)removeDepartureTimesObject:(DepartureTime *)value;
- (void)addDepartureTimes:(NSSet *)value;
- (void)removeDepartureTimes:(NSSet *)value;

@end

