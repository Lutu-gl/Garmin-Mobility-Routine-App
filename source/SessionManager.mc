using Toybox.ActivityRecording;
using Toybox.Activity;

// Wraps the activity recording. The sport mapping lives here as the single source of
// truth; the name comes from the routine that was picked and is what Garmin Connect (and
// therefore Strava) uses as the activity title instead of the default "Lunch/Morning
// Workout". Both routines are mostly strength work, so they record as strength training.
class SessionManager {

    const SPORT = Activity.SPORT_TRAINING;
    const SUB_SPORT = Activity.SUB_SPORT_STRENGTH_TRAINING;

    var mSession;

    function initialize() {
        mSession = null;
    }

    function isRecording() {
        return mSession != null && mSession.isRecording();
    }

    function start(name) {
        if (mSession == null) {
            mSession = ActivityRecording.createSession({
                :name => name,
                :sport => SPORT,
                :subSport => SUB_SPORT
            });
        }
        if (!mSession.isRecording()) {
            mSession.start();
        }
    }

    function saveAndFinish() {
        if (mSession != null) {
            if (mSession.isRecording()) { mSession.stop(); }
            mSession.save();
            mSession = null;
        }
    }

    function discard() {
        if (mSession != null) {
            if (mSession.isRecording()) { mSession.stop(); }
            mSession.discard();
            mSession = null;
        }
    }

    function saveIfRecording() {
        if (isRecording()) {
            saveAndFinish();
        }
    }
}
