// The routines the user can choose between at start: the morning mobility & strength
// routine on five days a week, the leg programme on the other two. Adding a routine
// means adding a CSV, a jsonData resource and one entry here — name, exercise count and
// duration all come out of the JSON, so there is nothing to keep in sync by hand.
//
// :session is the activity name Garmin Connect (and through it Strava) shows, so the
// two kinds of day are told apart at a glance while landing in the same category.
module RoutineCatalog {

    const MOBILITY = 0;
    const LEGS = 1;

    // Application.Storage key holding the index of the routine that ran last.
    const LAST_KEY = "lastRoutine";

    function all() {
        return [
            { :res => Rez.JsonData.routineData,     :session => "Daily-Mobility" },
            { :res => Rez.JsonData.routineLegsData, :session => "Daily-Legs" }
        ];
    }
}
