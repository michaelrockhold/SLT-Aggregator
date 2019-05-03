//
//  SoundTransitTimetableDownloader.m
//  LiveTransit-Seattle
//
//  Created by Michael Rockhold on 9/25/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import "SoundTransitTimetableDownloader.h"
#import "Route.h"
#import "Timepoint.h"
#import "Schedule.h"
#import <XPathQuery.h>
#import "Run.h"
#import "Stop.h"
#import "DepartureTime.h"
#import "Timetable.h"

@interface H2Handler : NSObject< XPathNodeHandler >
{
	NSMutableArray* m_timetables;
}
@property (nonatomic, readonly, retain) NSMutableArray* timetables;
@end

@implementation H2Handler
@synthesize timetables = m_timetables;

-(id)init
{
	if ( self = [super init] )
	{
		m_timetables = [[NSMutableArray arrayWithCapacity:10] retain];
	}
	return self;
}

-(void)dealloc
{
	[m_timetables release];
	[super dealloc];
}

- (void)handleNode:(XPathNode*)node
{
	if ( [node.attributes count] == 0 && [node.children count] == 0 )
	{
		NSMutableDictionary* timetable = [NSMutableDictionary dictionaryWithCapacity:2];
		[timetable setObject:node.content forKey:@"title"];
		[timetable setObject:[NSMutableArray arrayWithCapacity:5] forKey:@"rows"];
		[m_timetables addObject:timetable];
	}
}
@end

@interface RouteDirectoryBuildingHandler : NSObject< XPathNodeHandler >
{
	NSString* m_prefix;
	NSMutableDictionary* m_directory;
}
-(id)initWithURLPrefix:(NSString*)prefix;
-(NSString*)urlByRouteID:(int)routeID day:(ScheduleDay)day;
@property (nonatomic, readonly, retain) NSDictionary* routeDirectory;
@end
@implementation RouteDirectoryBuildingHandler
@synthesize routeDirectory = m_directory;
-(id)initWithURLPrefix:(NSString*)prefix;
{
	if ( self = [super init] )
	{
		m_prefix = [prefix retain];
		m_directory = [[NSMutableDictionary dictionaryWithCapacity:1] retain];
	}
	return self;
}

-(void)dealloc
{
	[m_directory release];
	[m_prefix release];
	[super dealloc];
}

-(NSString*)urlByRouteID:(int)routeID day:(ScheduleDay)day
{
	NSString* key = [NSString stringWithFormat:@"%d-%@", routeID, ( day == eWeekdaySchedule ) ? @"Weekday" : @"Weekend"];
	return [NSString stringWithFormat:@"%@/%@", m_prefix, [[m_directory objectForKey:key] objectForKey:@"url"]];
}

- (void)handleNode:(XPathNode*)node
{	
	if ( [node.content isEqual:@"Weekday" ] || [node.content isEqual:@"Weekend" ] )
	{
		NSMutableDictionary* route = [NSMutableDictionary dictionaryWithCapacity:3];
		[route setObject:node.content forKey:@"day"];
		
		for (XPathAttr* attr in node.attributes)
		{
			if ( [attr.name isEqual:@"href"] )
			{
				[route setObject:attr.content.content forKey:@"url"];
			}
			else if ( [attr.name isEqual:@"name"] )
			{
				[route setObject:[attr.content.content substringWithRange:NSMakeRange(0, 3)] forKey:@"routeID"];
				[route setObject:attr.content.content forKey:@"name"];
			}
		}
		
		NSString* key = [NSString stringWithFormat:@"%@-%@", [route objectForKey:@"routeID"], [route objectForKey:@"day"]];
		[m_directory setObject:route forKey:key];
	}
}
@end


@interface TrHandler : NSObject< XPathNodeHandler >
{
	int m_headers;
	NSUInteger m_timetableIndexForColumnHeaders;
	NSUInteger m_timetableIndexForRowHeaders;
	NSMutableArray* m_timetables;
}
@property (nonatomic, readonly, retain) NSArray* timetables;
@end
@implementation TrHandler
@synthesize timetables = m_timetables;

-(id)initWithTimetables:(NSMutableArray*)timetables
{
	if ( self = [super init] )
	{
		m_headers = 0;
		m_timetableIndexForColumnHeaders = 0;
		m_timetableIndexForRowHeaders = 0;
		m_timetables = [timetables retain];
	}
	return self;
}

-(void)dealloc
{
	[m_timetables release];
	[super dealloc];
}

- (void)handleNode:(XPathNode*)node
{	
	if ( [node.children count] == 0 ) return;
	
	XPathNode* kid = [node.children objectAtIndex:0];
	if ( [kid.name isEqualToString:@"th"] )
	{
		if ( m_headers % 2 == 0 )
		{
			NSMutableArray* columnHeaders = [NSMutableArray arrayWithCapacity:[node.children count]];
			for (XPathNode* k in node.children)
			{
				NSMutableString* columnHead = [k.content mutableCopy];
				if ( [columnHead hasSuffix:@"*"] )
					[columnHead deleteCharactersInRange:NSMakeRange(columnHead.length-1, 1)];
				[columnHeaders addObject:columnHead];
				[columnHead release];
			}
			[[m_timetables objectAtIndex:m_timetableIndexForColumnHeaders++] setObject:columnHeaders forKey:@"columnHeaders"];
		}
		m_headers++;
	}
	else if ( [kid.name isEqualToString:@"td"] )
	{
		if ( m_headers % 2 == 1 )
		{
			NSMutableArray* row = [NSMutableArray arrayWithCapacity:[node.children count]];
			for (XPathNode* k in node.children)
				[row addObject:k.content];
			[[[m_timetables objectAtIndex:m_timetableIndexForRowHeaders++] objectForKey:@"rows"] addObject:row];
		}
	}
}
@end

static RouteDirectoryBuildingHandler* s_routeDirectoryBuildingHandler = nil;

@implementation SoundTransitTimetableDownloader

+(void)initialize
{
	if ( self == [SoundTransitTimetableDownloader class] )
	{
		NSURL* url = [NSURL URLWithString:@"http://www.soundtransit.org/Riding-Sound-Transit/Schedules-and-Facilities/ST-Express-Bus.xml"];
		NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:10];
		NSHTTPURLResponse* response = nil;
		NSData* responseData = nil;
		NSError* error = nil;
		@try
		{
			responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
			s_routeDirectoryBuildingHandler = [[RouteDirectoryBuildingHandler alloc] initWithURLPrefix:@"http://soundtransit.org"];
			[XPathNode performHTMLXPathQueryOnDocument:responseData 
												 Query:@"//div[@id='body']//td/a" 
												Prefix:@"" 
											 Namespace:@"" 
									  XPathNodeHandler:s_routeDirectoryBuildingHandler];	
		}
		@catch (NSException* e)
		{
		}
	}
}

-(NSURLRequest*)makeURLRequest
{
	return [NSURLRequest requestWithURL:[NSURL URLWithString:[s_routeDirectoryBuildingHandler urlByRouteID:m_route day:m_day]]
							cachePolicy:NSURLRequestUseProtocolCachePolicy
						timeoutInterval:60.0];
}

-(void)parseScheduleData:(NSData*)data
{
	H2Handler* h2Handler = [[H2Handler alloc] init];
	[XPathNode performHTMLXPathQueryOnDocument:data 
										Query:@"//div[@id='body']//h2[position()>1]" 
									   Prefix:@"" 
									Namespace:@"" 
							 XPathNodeHandler:h2Handler];
	
	TrHandler* trHandler = [[TrHandler alloc] initWithTimetables:h2Handler.timetables];
	[XPathNode performHTMLXPathQueryOnDocument:data 
										Query:@"//div[@id='body']//tbody/tr" 
									   Prefix:@"" 
									Namespace:@"" 
							 XPathNodeHandler:trHandler];
	
	for (NSDictionary* ttDict in trHandler.timetables)
	{
		BOOL fWeekday = NO;
		BOOL fSaturday = NO;
		BOOL fSunday = NO;
		NSMutableString* title = [[ttDict objectForKey:@"title"] mutableCopy];
		
		NSRange weekdaysRange = [title rangeOfString:@" (Weekdays)"];
		NSRange weekendsRange = [title rangeOfString:@" (Weekends)"];
		NSRange saturdayRange = [title rangeOfString:@" (Saturday)"];
		NSRange saturdaysRange = [title rangeOfString:@" (Saturdays)"];
		NSRange sundayRange = [title rangeOfString:@" (Sunday)"];
		NSRange sundaysRange = [title rangeOfString:@" (Sundays)"];
		NSRange weekdaysOnlyRange = [title rangeOfString:@" (Weekdays Only)"];
		if ( weekdaysRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:weekdaysRange withString:@""];
			fWeekday = YES;
		}
		else if ( saturdayRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:saturdayRange withString:@""];
			fSaturday = YES;
		}
		else if ( saturdaysRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:saturdaysRange withString:@""];
			fSaturday = YES;
		}
		else if ( sundayRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:sundayRange withString:@""];
			fSunday = YES;
		}
		else if ( sundaysRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:sundaysRange withString:@""];
			fSunday = YES;
		}
		else if ( weekendsRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:weekendsRange withString:@""];
			fSaturday = YES;
			fSunday = YES;
		}
		else if ( weekdaysOnlyRange.location != NSNotFound )
		{
			[title replaceCharactersInRange:weekdaysOnlyRange withString:@""];
			fWeekday = YES;
		}
		else
		{
			fWeekday = YES;
		}

		NSArray* runsArray = [ttDict objectForKey:@"rows"];
		NSArray* timepointNames = [ttDict objectForKey:@"columnHeaders"];

		NSMutableSet* stops = [NSMutableSet setWithCapacity:[timepointNames count]];
		NSMutableArray* runs = [NSMutableArray arrayWithCapacity:[runsArray count]];
		
		NSUInteger nthRun = 0;
		for (NSArray* runArray in runsArray)
		{
			Run* run = [self newRunWithIndex:nthRun++];
			[runs addObject:run];
			[run release];
		}
		
		NSUInteger nthStop = 0;
		for (NSString* name in timepointNames)
		{
			Stop* stop = [self newStopWithInfo:name index:nthStop];

			nthRun = 0;
			for (NSArray* runArray in runsArray)
			{
				Run* run = [runs objectAtIndex:nthRun];
				
				DepartureTime* departure = [self newDepartureTimeWithInfo:[runArray objectAtIndex:nthStop]
																   stopIndex:nthStop 
																	runIndex:nthRun 
																		 run:run 
																		stop:stop];
				[departure release];
			}
			
			Timepoint* tp = [self timepointByVariantOfName:name];
			if ( tp != nil )
			{
				stop.timepoint = tp;
				NSLog(@"STATUS: TIMEPOINT MATCH: \"%@\" matches timepoint ID %@ (%@) for route/day %d/%d\n", name, tp.ID, tp.name, m_route, m_day);
			}
			else 
			{
				m_missingTimepointErrors++;
				NSLog(@"WARNING: TIMEPOINT NO MATCH: \"%@\" for route/day %d/%d\n", name, m_route, m_day);
			}
			nthStop++;
			
			[stops addObject:stop];
			[stop release];
		}
				
		NSDate* tomorrow = [NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24)];
		NSSet* runsSet = [NSSet setWithArray:runs];
		
		if ( fWeekday )
		{
			Timetable* tt = [self newTimetable:title expirationDate:tomorrow dayCode:eWeekdaySchedule stops:stops runs:runsSet];
			[m_timetables addObject:tt];
			[tt release];
		}
		if ( fSaturday )
		{
			Timetable* tt = [self newTimetable:title expirationDate:tomorrow dayCode:eSaturdaySchedule stops:stops runs:runsSet];
			[m_timetables addObject:tt];
			[tt release];
		}
		if ( fSunday )
		{
			Timetable* tt = [self newTimetable:title expirationDate:tomorrow dayCode:eSundaySchedule stops:stops runs:runsSet];
			[m_timetables addObject:tt];
			[tt release];
		}
		[title release];
	}
		
	[h2Handler release];
	[trHandler release];
}

@end