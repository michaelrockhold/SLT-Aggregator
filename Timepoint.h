//
//  Timepoint.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Stop;
@class TimepointAlias;

@interface Timepoint :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * ID;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) id location;
@property (nonatomic, retain) NSSet* stops;
@property (nonatomic, retain) NSSet* aliases;

@end


@interface Timepoint (CoreDataGeneratedAccessors)
- (void)addStopsObject:(Stop *)value;
- (void)removeStopsObject:(Stop *)value;
- (void)addStops:(NSSet *)value;
- (void)removeStops:(NSSet *)value;

- (void)addAliasesObject:(TimepointAlias *)value;
- (void)removeAliasesObject:(TimepointAlias *)value;
- (void)addAliases:(NSSet *)value;
- (void)removeAliases:(NSSet *)value;

@end

