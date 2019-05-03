//
//  DepartureTime.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Run;
@class Stop;

@interface DepartureTime :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * info;
@property (nonatomic, retain) Stop * stop;
@property (nonatomic, retain) Run * run;

@end



