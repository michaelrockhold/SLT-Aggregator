//
//  MetroTimetableDownloader.m
//  LiveTransit-Seattle
//
//  Created by Michael Rockhold on 9/25/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import "MetroTimetableDownloader.h"
#import "Timepoint.h"
#import "Route.h"
#import "Run.h"
#import "DepartureTime.h"
#import "Stop.h"

#pragma mark Internal implementation classes

@interface LTRange : NSObject
{
	NSUInteger m_location;
	NSUInteger m_length;
}
-(id)initWithLocation:(NSUInteger)location length:(NSUInteger)length;
-(id)initWithRange:(NSRange)range;

@property (nonatomic) NSUInteger location;
@property (nonatomic) NSUInteger length;
@property (nonatomic) NSRange range;
@end

@implementation LTRange
@synthesize location = m_location, length = m_length;

-(id)initWithLocation:(NSUInteger)location length:(NSUInteger)length
{
	if (nil != (self = [super init]) )
	{
		m_location = location;
		m_length = length;
	}
	return self;
}

-(id)initWithRange:(NSRange)range
{
	return [self initWithLocation:range.location length:range.length];
}

-(NSRange)range
{
	return NSMakeRange(self.location, self.length);
}

-(void)setRange:(NSRange)range
{
	self.location = range.location;
	self.length = range.length;
}
@end

@interface LineEnumerator : NSEnumerator
{
	NSString* m_srcText;
	NSRange m_range;
	NSUInteger m_rangeEnd;
	NSUInteger m_cursor;
}

-(id)initWithSrc:(NSString*)s within:(NSRange)within;
@end

@implementation LineEnumerator

-(id)initWithSrc:(NSString*)s within:(NSRange)within
{
	if ( self = [super init] )
	{
		m_srcText = [s retain];
		m_range = within;
		m_cursor = within.location;
		m_rangeEnd = within.location + within.length;
	}
	return self;
}

-(void)dealloc
{
	[m_srcText release];
	[super dealloc];
}

-(id)nextObject
{
	@try
	{
		if ( !NSLocationInRange(m_cursor, m_range) )
			return nil;
		
		NSUInteger lineEndIndex, contentsEndIndex;
		[m_srcText getLineStart:NULL end:&lineEndIndex contentsEnd:&contentsEndIndex forRange:NSMakeRange(m_cursor, 1)];
		
		if ( contentsEndIndex > m_rangeEnd )
		{
			contentsEndIndex = m_rangeEnd;
		}
		
		if ( lineEndIndex > m_rangeEnd )
		{
			lineEndIndex = m_rangeEnd;
		}
		
		LTRange* returnRange = [[[LTRange alloc] initWithLocation:m_cursor length:contentsEndIndex - m_cursor] autorelease];
		
		m_cursor = lineEndIndex;
		
		return returnRange;
	}
	@catch (NSException * e)
	{
		return nil;
	}
	return nil;
}
@end

@interface TimetableRunsEnumerator : NSEnumerator
{
	NSUInteger m_cursor;
	LineEnumerator* m_lineEnumerator;
	NSUInteger m_startingOffsetIntoEachLine;
	NSUInteger m_columnCount;
	NSUInteger m_columnWidth;
}

-(id)initWithLineEnumerator:(LineEnumerator*)lineEnumerator startingOffsetIntoEachLine:(NSUInteger)startingOffsetIntoEachLine columns:(NSUInteger)columnCount columnWidth:(NSUInteger)columnWidth;

@end

@implementation TimetableRunsEnumerator

-(id)initWithLineEnumerator:(LineEnumerator*)lineEnumerator startingOffsetIntoEachLine:(NSUInteger)startingOffsetIntoEachLine columns:(NSUInteger)columnCount columnWidth:(NSUInteger)columnWidth
{
	if ( self = [super init] )
	{
		m_lineEnumerator = [lineEnumerator retain];	
		m_columnCount = columnCount;
		m_startingOffsetIntoEachLine = startingOffsetIntoEachLine;
		m_columnWidth = columnWidth;
	}
	return self;
}

-(void)dealloc
{
	[m_lineEnumerator release];
	[super dealloc];
}

-(id)nextObject
{
	LTRange* lineRng;
	do {
		lineRng = [m_lineEnumerator nextObject];
		if ( nil == lineRng )
			return nil;
	} while (lineRng.length < m_startingOffsetIntoEachLine + m_columnCount * m_columnWidth);
	
	NSMutableArray* timePoints = [NSMutableArray arrayWithCapacity:m_columnCount];
	NSUInteger loc = lineRng.location + m_startingOffsetIntoEachLine;
	for (int i = 0; i < m_columnCount; i++)
	{
		LTRange* robj = [[LTRange alloc] initWithLocation:loc length:m_columnWidth];
		[timePoints addObject:robj];
		[robj release];
		loc += m_columnWidth;
	}
	
	return timePoints;	
}
@end


static NSArray* match(NSString* srcString, NSUInteger startFrom, NSUInteger* pBeginningPosition, NSUInteger* pEndPosition, NSArray* nodes)
{
	NSMutableArray* results = [NSMutableArray arrayWithCapacity:5];
	
	NSUInteger cursor = startFrom;
	
	if ( [nodes count] < 2 ) return nil;
	
	NSUInteger nodeIndex = 0;	
	NSRange match = [srcString rangeOfString:[nodes objectAtIndex:nodeIndex] 
									 options:NSCaseInsensitiveSearch 
									   range:NSMakeRange(cursor, srcString.length - cursor)];
	if ( match.location == NSNotFound ) return nil;
	*pBeginningPosition = match.location;	
	
	for (nodeIndex=1 ; nodeIndex < [nodes count]; nodeIndex++)
	{
		NSUInteger cursor = match.location + match.length;
		match = [srcString rangeOfString:[nodes objectAtIndex:nodeIndex] 
								 options:NSCaseInsensitiveSearch 
								   range:NSMakeRange(cursor, srcString.length - cursor)];
		if ( match.location == NSNotFound ) return nil;		
		*pEndPosition = match.location + match.length;
		
		LTRange* result = [[LTRange alloc] initWithLocation:cursor length:(match.location-cursor)];
		[results addObject:result];
		[result release];
	}
	
	return results;
}

static NSArray* makeColumnHeaders(NSString* srcString, NSRange within, NSUInteger* pStartPosition)
{
	*pStartPosition = 0;
	NSUInteger columnWidth = 13;
	NSMutableArray* columnHeaders = [NSMutableArray array];
	
	LineEnumerator* le = [[LineEnumerator alloc] initWithSrc:srcString within:within];
	NSArray* lines = [le allObjects];
	
	if ( [[srcString substringWithRange:[[lines objectAtIndex:2] range]] hasPrefix:@"Route"] )
	{
		*pStartPosition = 5;
	}
	else
	{
		*pStartPosition = 2;
	}
	
	for ( LTRange* lineRng in lines )
	{
		if ( lineRng.length < *pStartPosition + columnWidth ) continue;
		
		int i = 0;
		NSRange q = NSMakeRange(lineRng.location + *pStartPosition, columnWidth);
		
		do
		{
			NSString* h = nil;
			@try
			{
					//cases: q is within current line lineRng: continue
					// q starts in lineRng but slops out: truncate q
					// q is no longer in lineRng: break out of this loop, we're done
				if ( !NSLocationInRange(q.location, lineRng.range) )
					break;
				else 
					q = NSIntersectionRange(lineRng.range, q);
				
				h = [[srcString substringWithRange:q] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				q.location += q.length;
				i++;
				
				if ( [columnHeaders count] < i )
				{
					[columnHeaders addObject:[NSMutableString stringWithString:h]];
				}
				else
				{
					[[columnHeaders objectAtIndex:i-1] appendFormat:@" %@", h];
				}
			}
			@catch (NSException * e)
			{
				break;
			}
		} while (TRUE);
	}
	
	[le release];
	
	NSMutableArray* trimmedColumnHeaders = [NSMutableArray arrayWithCapacity:[columnHeaders count]];
	for (NSString* c in columnHeaders)
	{
		NSString* h = [c stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if ( ![h isEqualToString:@"To Route"] )
			[trimmedColumnHeaders addObject:h];
	}
	
	return trimmedColumnHeaders;
}

@implementation MetroTimetableDownloader

-(NSURLRequest*)makeURLRequest
{
	static NSString* schedFormat = @"http://metro.kingcounty.gov/tops/bus/schedules/s%03d_%d_.html";
	return [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:schedFormat, m_route, m_day]]
							cachePolicy:NSURLRequestUseProtocolCachePolicy
						timeoutInterval:60.0];
}

-(void)parseScheduleData:(NSData*)data
{
	NSMutableString* pageText = [[[NSMutableString alloc] initWithBytes:[data bytes]
																 length:[data length]
															   encoding:NSUTF8StringEncoding] autorelease];
	if ( pageText == nil )
	{
		m_parsingErrors++;
		NSLog(@"WARNING: data, but no text for route/day %d/%d\n", m_route, m_day);
		return;
	}
	
	[pageText replaceOccurrencesOfString:@"&#167;" withString:@"§" options:NSCaseInsensitiveSearch range:NSMakeRange(0, pageText.length)]; // TODO: generalize	
	
	NSRange r = [pageText rangeOfString:@"<!-- end timetable bar nav -->"];
	if ( r.location == NSNotFound )
	{
		m_parsingErrors++;
		NSLog(@"WARNING: text for route/day %d/%d does not appear to contain valid KCM timetable\n", m_route, m_day);
		return; //return [NSError errorWithDomain:@"timetableparsing.rockholdco.com" code:1 userInfo:nil];
	}
	
	NSArray* matchNodes = [NSArray arrayWithObjects:@"<h5>", @":</h5><pre>", @"<br />", @"</pre>", nil];
	NSUInteger beginningPosition = 0;
	NSUInteger endPosition = 0;
	NSArray* matches = nil;
	NSUInteger startSearchLocation = r.location + r.length;
	while ( matches = match(pageText, startSearchLocation, &beginningPosition, &endPosition, matchNodes) )
	{
			// Title range is matches[0]
			// raw column headers in matches[1]
			// timetable runs in matches[2]
		NSUInteger runStartOffset = 0;
		NSArray* timepointNames = makeColumnHeaders(pageText, [[matches objectAtIndex:1] range], &runStartOffset);
		
		LineEnumerator* lineEnumerator = [[LineEnumerator alloc] initWithSrc:pageText within:[[matches objectAtIndex:2] range]];		
		TimetableRunsEnumerator* runsE = [[TimetableRunsEnumerator alloc] initWithLineEnumerator:lineEnumerator 
																	  startingOffsetIntoEachLine:runStartOffset 
																						 columns:[timepointNames count]
																					 columnWidth:13];
		
		NSArray* arrayOfArraysOfRanges = [runsE allObjects];// ie, one element in this list for each Run
		[lineEnumerator release];
		[runsE release];
		
		NSString* title = [[pageText substringWithRange:[[matches objectAtIndex:0] range]] stringByReplacingOccurrencesOfString:@" (Weekday)" withString:@""];
		title = [title stringByReplacingOccurrencesOfString:@" (Saturday)" withString:@""];
		title = [title stringByReplacingOccurrencesOfString:@" (Sunday)" withString:@""];
		
		NSMutableSet* stops = [NSMutableSet setWithCapacity:[timepointNames count]];
		NSMutableArray* runs = [NSMutableArray arrayWithCapacity:[arrayOfArraysOfRanges count]];
		
		for (int n = 0; n < [arrayOfArraysOfRanges count]; n++)
		{
			Run* run = [self newRunWithIndex:n];			
			[runs addObject:run];
			[run release];
		}
		
		for (int nthStop = 0; nthStop < [timepointNames count]; nthStop++)
		{
			NSString* name = [timepointNames objectAtIndex:nthStop];
			Stop* stop = [self newStopWithInfo:name index:nthStop];
			
			for (int nthRun = 0; nthRun < [arrayOfArraysOfRanges count]; nthRun++)
			{
				Run* run = [runs objectAtIndex:nthRun];
				LTRange* departureInfoRange = [[arrayOfArraysOfRanges objectAtIndex:nthRun] objectAtIndex:nthStop];
				
				DepartureTime* departure = [self newDepartureTimeWithInfo:[pageText substringWithRange:departureInfoRange.range]
																stopIndex:(NSUInteger)nthStop 
																 runIndex:(NSUInteger)nthRun 
																	  run:run 
																	 stop:stop];
				[departure release];
			}
			
			Timepoint* tp = [self timepointByVariantOfName:name];
			if ( tp != nil )
			{
				stop.timepoint = tp;
			}
			else 
			{
				m_missingTimepointErrors++;
				NSLog(@"WARNING: TIMEPOINT NO MATCH: \"%@\" for route/day %d/%d/%d\n", name, m_route, m_day, nthStop);
			}
			
			[stops addObject:stop];
			[stop release];
		}
		
		[m_timetables addObject:[self newTimetable:title
								  expirationDate:[NSDate dateWithTimeIntervalSinceNow:(60 * 60 * 24)] 
										 dayCode:m_day 
										   stops:stops 
											runs:[NSSet setWithArray:runs]]];
		
		startSearchLocation = endPosition;
	}
}

@end
