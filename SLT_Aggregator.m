//
//  SLT_Aggregator.m
//  SLT-Aggregator
//
//  Created by Michael Rockhold on 11/7/09.
//  Copyright The Rockhold Company 2009 . All rights reserved.
//

#import <objc/objc-auto.h>
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#import "Timepoint.h"
#import "TimepointAlias.h"
#import "Route.h"

#import "TimetableDownloader.h"
#import "MetroTimetableDownloader.h"
#import "SoundTransitTimetableDownloader.h"


NSManagedObjectModel* managedObjectModel();
NSManagedObjectContext* managedObjectContext();

void save();
void loadTimepoints(NSDictionary* config);
void newTimepointFromDictionary(NSDictionary* d);
void newTimepointAliasFromDictionary(NSDictionary* d);

void loadRoutes();

int main (int argc, const char * argv[])
{
    objc_startCollectorThread();
		
		// read the config file named in the first argument, or quit if you can't;
		// config file has path of routes list file, path of timepoints list file, and expiration date to use
	if ( argc != 2)
	{
		NSLog(@"usage error");
		exit(1);
	}
	
	NSDictionary* configDict = [NSDictionary dictionaryWithContentsOfURL:[NSURL fileURLWithPath:[NSString stringWithCString:argv[1]]]];
	
	
		// read the list of (potential?) routes
	
		// read the list of timepoints
	loadTimepoints(configDict);
	
		// for each day (weekday | Saturday | Sunday) in each route, download the timetables
	
	save();
	
	loadRoutes();
	
	save();
	
		// for each route, traverse the object graph; build one big NSXMLDocument containing the aggregate of all of them
	
		// Write out the NSXMLDocument to the standard output
	
		// OR maybe just use the XML object store file directly? Massage it with desktop XML tools or something?

    return 0;
}



NSManagedObjectModel* managedObjectModel()
{
    static NSManagedObjectModel *model = nil;
	if ( model == nil )
	{    
		NSString *path = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
		path = [path stringByDeletingPathExtension];
		NSURL *modelURL = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"mom"]];
		model = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    }
    return model;
}



NSManagedObjectContext* managedObjectContext()
{
    static NSManagedObjectContext *context = nil;
    if ( context == nil )
	{    
		context = [[NSManagedObjectContext alloc] init];
		
		NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: managedObjectModel()];
		[context setPersistentStoreCoordinator: coordinator];
		
		NSString* STORE_TYPE = NSSQLiteStoreType;
		
		NSString *path = [[[NSProcessInfo processInfo] arguments] objectAtIndex:0];
		path = [path stringByDeletingPathExtension];
		NSURL *url = [NSURL fileURLWithPath:[path stringByAppendingPathExtension:@"sqlite"]];
		
		NSError *error;
		NSPersistentStore *newStore = [coordinator addPersistentStoreWithType:STORE_TYPE configuration:nil URL:url options:nil error:&error];
		
		if ( newStore == nil )
		{
			NSLog(@"Store Configuration Failure\n%@",
				  ([error localizedDescription] != nil) ?
				  [error localizedDescription] : @"Unknown Error");
		}
	}
    return context;
}

void save()
{
	NSError* error = nil;
    if ( managedObjectContext() != nil )
	{
        if ( [managedObjectContext() hasChanges] && ![managedObjectContext() save:&error] )
		{
				// TODO: Handle error more informatively
			NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        } 
    }
}

void newTimepointFromDictionary(NSDictionary* d)
{
	Timepoint* timepoint = [NSEntityDescription insertNewObjectForEntityForName:@"Timepoint" inManagedObjectContext:managedObjectContext()];
	
	timepoint.name = [d objectForKey:@"name"];
	timepoint.ID = [d objectForKey:@"ID"];
	
	CLLocationCoordinate2D coord;
	coord.latitude = [[d objectForKey:@"latitude"] doubleValue];
	coord.longitude = [[d objectForKey:@"longitude"] doubleValue];
	
	timepoint.location = [[[CLLocation alloc] initWithCoordinate:coord 
														altitude:0
											  horizontalAccuracy:kCLLocationAccuracyBest 
												verticalAccuracy:kCLLocationAccuracyBest 
													   timestamp:nil] autorelease];
	
	NSLog(@"STATUS: inserting new timepoint ID %@ (%@)\n", timepoint.ID, timepoint.name);
}


void newTimepointAliasFromDictionary(NSDictionary* d)
{
	NSString* timepointID = [d objectForKey:@"ID"];
	
	NSFetchRequest* request = [[NSFetchRequest alloc] init];
	[request setReturnsObjectsAsFaults:NO];
	request.entity = [NSEntityDescription entityForName:@"Timepoint" inManagedObjectContext:managedObjectContext()];
	request.predicate = [NSPredicate predicateWithFormat:@"ID == %@", timepointID];
	
	NSError* error = nil;
	NSArray* timepoints = [managedObjectContext() executeFetchRequest:request error:&error];
	[request release];
	if ( timepoints.count != 1 )
	{
		NSLog(@"WARNING: No timepoint with ID == %@\n", timepointID);
		return;
	}
	else 
	{
		NSLog(@"STATUS: Timepoint alias %@ matches timepoint ID %@\n", [d objectForKey:@"alias"], timepointID);
	
		TimepointAlias* timepointAlias = [NSEntityDescription insertNewObjectForEntityForName:@"TimepointAlias" inManagedObjectContext:managedObjectContext()];

		timepointAlias.name = [d objectForKey:@"alias"];
		timepointAlias.timepoint = [timepoints objectAtIndex:0];
	}
	
}


void loadTimepoints(NSDictionary* config)
{
	NSArray* plist = [NSArray arrayWithContentsOfFile:[config objectForKey:@"timepointsFile"]];
	if ( !plist )
	{
		NSLog(@"error reading timepoint list\n");
	}
	else 
	{
		for (NSDictionary* d in plist)
		{
			newTimepointFromDictionary(d);
		}
	}

	plist = [NSArray arrayWithContentsOfFile:[config objectForKey:@"timepointAliasesFile"]];
	if ( !plist )
	{
		NSLog(@"error reading timepoint alias list\n");
	}
	else 
	{
		for (NSDictionary* d in plist)
		{
			newTimepointAliasFromDictionary(d);
		}
	}		
}

void loadRoute(int rID)
{
		// exceptions
	if ( rID == 98 ) return;
	
	NSLog(@"STATUS: downloading timetables for route %d\n", rID);

	NSMutableArray* downloaders = [NSMutableArray arrayWithCapacity:3];
	NSMutableSet* timetables = [NSMutableSet setWithCapacity:6];
	int scheduleCount = 0;
	int badScheduleCount = 0;
	
	TimetableDownloader* ttdl;
	if ( rID >= 500 && rID < 600 )
	{
		ttdl = [[SoundTransitTimetableDownloader alloc] initWithRoute:rID day:eWeekdaySchedule];
		[downloaders addObject:ttdl]; [ttdl release];
		
		ttdl = [[SoundTransitTimetableDownloader alloc] initWithRoute:rID day:eWeekendSchedule];
		[downloaders addObject:ttdl]; [ttdl release];
	}
	else
	{
		ttdl = [[MetroTimetableDownloader alloc] initWithRoute:rID day:eWeekdaySchedule];
		[downloaders addObject:ttdl]; [ttdl release];
		
		ttdl = [[MetroTimetableDownloader alloc] initWithRoute:rID day:eSaturdaySchedule];
		[downloaders addObject:ttdl]; [ttdl release];
		
		ttdl = [[MetroTimetableDownloader alloc] initWithRoute:rID day:eSundaySchedule];
		[downloaders addObject:ttdl]; [ttdl release];
	}
	
	for (TimetableDownloader* d in downloaders)
	{
		[d download];
		[timetables unionSet:d.timetables];
		if ( d.validSchedule ) scheduleCount++;
		else badScheduleCount++;
	}
	
	if ( timetables.count > 0 )
	{
		Route* r = [NSEntityDescription insertNewObjectForEntityForName:@"Route" inManagedObjectContext:managedObjectContext()];
		r.ID = [NSString stringWithFormat:@"%d", rID];
		[r addTimetables:timetables];
	}
	NSLog(@"STATUS: done with route %d: %d timetables in %d valid schedules, %d invalid\n", rID, timetables.count, scheduleCount, badScheduleCount);
}

void loadRoutes()
{		
	for ( int rID = 1; rID < 999; rID++)
		loadRoute(rID);
}
