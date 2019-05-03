//
//  TimetableDownloader.h
//  LiveTransit-Seattle
//
//  Created by Michael Rockhold on 9/5/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Schedule.h"

@class Run;
@class Stop;
@class DepartureTime;
@class Timetable;
@class TimepointAlias;
@class Timepoint;

@interface TimetableDownloader : NSObject
{
	int m_route;
	int m_day;
	
	NSMutableSet* m_timetables;
	BOOL m_validSchedule;
	int m_missingTimepointErrors;
	int m_parsingErrors;
}

@property (nonatomic, readonly) BOOL validSchedule;
@property (nonatomic, readonly, retain) NSSet* timetables;
@property (nonatomic, readonly) int missingTimepointErrors;
@property (nonatomic, readonly) int parsingErrors;

-(id)initWithRoute:(int)r day:(ScheduleDay)day;

-(NSURLRequest*)makeURLRequest; // abstract

-(void)parseScheduleData:(NSData*)data; // abstract

-(void)download;

-(Run*)newRunWithIndex:(NSUInteger)index;

-(Stop*)newStopWithInfo:(NSString*)info 
				  index:(NSUInteger)index;

-(DepartureTime*)newDepartureTimeWithInfo:(NSString*)info 
								stopIndex:(NSUInteger)stopIndex 
								 runIndex:(NSUInteger)runIndex 
									  run:(Run*)run 
									 stop:(Stop*)stop;

-(Timetable*)newTimetable:(NSString*)title
		   expirationDate:(NSDate*)expirationDate 
				  dayCode:(ScheduleDay)dayCode 
					stops:(NSSet*)stops
					 runs:(NSSet*)runs;

-(TimepointAlias*)timepointAliasByName:(NSString*)name;

-(Timepoint*)timepointByVariantOfName:(NSString*)name;

@end