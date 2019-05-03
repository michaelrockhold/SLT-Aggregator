//
//  Schedule.h
//  LiveTransit-Seattle
//
//  Created by Michael Rockhold on 9/24/09.
//  Copyright 2009 The Rockhold Company. All rights reserved.
//

#import <Foundation/Foundation.h>

enum ScheduleDay
{
	eWeekdaySchedule = 0,
	eSaturdaySchedule = 1,
	eSundaySchedule = 2,
	eWeekendSchedule = 3
};
typedef enum ScheduleDay ScheduleDay;
