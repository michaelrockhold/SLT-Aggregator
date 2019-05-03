//
//  TimetableDownloader.m
//  LiveTransit-Seattle
//
//  Created by Michael Rockhold on 9/5/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import "TimetableDownloader.h"
#import "Timepoint.h"
#import "Timetable.h"
#import "Run.h"
#import "Stop.h"
#import "DepartureTime.h"
#import "TimepointAlias.h"

NSManagedObjectContext* managedObjectContext();

NSPredicate* nameLikePredicateTemplate()
{
	static NSPredicate* nameLikePredicateTemplate = nil;
	if ( nameLikePredicateTemplate == nil )
		nameLikePredicateTemplate = [[NSPredicate predicateWithFormat:@"name LIKE[cd] $NAME"] retain];
	return nameLikePredicateTemplate;
}


NSEntityDescription* timepointAliasEntity()
{
	static NSEntityDescription* timepointAliasEntity = nil;
	
	if ( !timepointAliasEntity )
		timepointAliasEntity = [[NSEntityDescription entityForName:@"TimepointAlias" inManagedObjectContext:managedObjectContext()] retain];
	return timepointAliasEntity;
}

@implementation TimetableDownloader
@synthesize timetables = m_timetables;
@synthesize missingTimepointErrors = m_missingTimepointErrors, parsingErrors = m_parsingErrors;

-(id)initWithRoute:(int)r day:(ScheduleDay)day
{
	if ( self = [super init] )
	{
		m_route = r;
		m_day = day;
		m_missingTimepointErrors = 0;
		m_parsingErrors = 0;
		m_timetables = [NSMutableSet setWithCapacity:4];
		m_validSchedule = NO;
	}
	return self;
}

-(BOOL)validSchedule
{
	return m_timetables.count > 0;
}

-(NSURLRequest*)makeURLRequest // abstract
{
	return nil;
}

-(void)parseScheduleData:(NSData*)data // abstract
{
}

-(void)download
{
	NSLog(   @"STATUS:      timetables for day %d\n", m_day);
	
	NSURLResponse* response = nil;
	NSError* error = nil;
	NSData* data = [NSURLConnection sendSynchronousRequest:[self makeURLRequest] returningResponse:&response error:&error];
	
	if ( data )
	{
		[self parseScheduleData:data];
	}
	else
	{
		NSLog(@"WARNING:     no data for route/day %d/%d\n", m_route, m_day);
	}
	if ( self.validSchedule )
		NSLog(@"STATUS:      end gathering timetables for day %d: missing timepoint errors %d\n", m_day, m_missingTimepointErrors);
	else
		NSLog(@"STATUS:      end gathering timetables for day %d: invalid schedule\n", m_day);

}

-(Run*)newRunWithIndex:(NSUInteger)index
{
	Run* run = [NSEntityDescription insertNewObjectForEntityForName:@"Run" inManagedObjectContext:managedObjectContext()];

	run.index = [NSNumber numberWithUnsignedInt:index];
	return run;
}

-(Stop*)newStopWithInfo:(NSString*)info index:(NSUInteger)index
{
	Stop* stop = [NSEntityDescription insertNewObjectForEntityForName:@"Stop" inManagedObjectContext:managedObjectContext()];

	stop.index = [NSNumber numberWithInt:index];
	stop.info = info;
	
	return stop;
}

-(DepartureTime*)newDepartureTimeWithInfo:(NSString*)info stopIndex:(NSUInteger)stopIndex runIndex:(NSUInteger)runIndex run:(Run*)run stop:(Stop*)stop
{
	DepartureTime* departure = [NSEntityDescription insertNewObjectForEntityForName:@"DepartureTime" inManagedObjectContext:managedObjectContext()];
	
	departure.info = info;
		//departure.stopIndex = [NSNumber numberWithUnsignedInt:stopIndex];
		//departure.runIndex = [NSNumber numberWithUnsignedInt:runIndex];
	departure.run = run;
	departure.stop = stop;
	
	[stop addDepartureTimesObject:departure];
	[run addDepartureTimesObject:departure];
	
	return departure;
}

-(Timetable*)newTimetable:(NSString*)title
		   expirationDate:(NSDate*)expirationDate 
				  dayCode:(ScheduleDay)dayCode 
					stops:(NSSet*)stops
					 runs:(NSSet*)runs
{
	Timetable* timetable = [NSEntityDescription insertNewObjectForEntityForName:@"Timetable" inManagedObjectContext:managedObjectContext()];
	
	timetable.title = title;
	timetable.expirationDate = expirationDate;
	timetable.dayCode = [NSNumber numberWithInt:dayCode];
	[timetable addStops:stops];
	[timetable addRuns:runs];
	
	return timetable;
}

-(TimepointAlias*)timepointAliasByName:(NSString*)name
{
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setReturnsObjectsAsFaults:NO];
	request.entity = timepointAliasEntity();
	request.predicate = [nameLikePredicateTemplate() predicateWithSubstitutionVariables:[NSDictionary dictionaryWithObject:name forKey:@"NAME"]];
	NSError* error = nil;
	NSArray* array = [managedObjectContext() executeFetchRequest:request error:&error];
	[request release];
	
	return ( array != nil && array.count > 0 ) ? [array objectAtIndex:0] : nil;
}

-(Timepoint*)timepointByVariantOfName:(NSString*)name
{
	TimepointAlias* tpa = [self timepointAliasByName:[name uppercaseString]];
	if ( tpa == nil ) return nil;
	
	return tpa.timepoint;
}

@end
