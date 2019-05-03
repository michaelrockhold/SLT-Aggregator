//
//  TimepointAlias.h
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <CoreData/CoreData.h>

@class Timepoint;

@interface TimepointAlias :  NSManagedObject  
{
}

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) Timepoint * timepoint;

@end



