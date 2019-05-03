//
//  Route.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Timetable;

@interface Route :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * ID;
@property (nonatomic, retain) NSSet* timetables;

@end


@interface Route (CoreDataGeneratedAccessors)
- (void)addTimetablesObject:(Timetable *)value;
- (void)removeTimetablesObject:(Timetable *)value;
- (void)addTimetables:(NSSet *)value;
- (void)removeTimetables:(NSSet *)value;

@end

