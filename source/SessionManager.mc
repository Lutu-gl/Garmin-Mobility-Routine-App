using Toybox.ActivityRecording;
using Toybox.Activity;

// Wraps the activity recording. The session name and sport mapping live here as the
// single source of truth: switching SUB_SPORT to SUB_SPORT_STRENGTH_TRAINING makes
// the activity show up as "Weight Training" in Strava instead of "Workout".
class SessionManager {

    const SESSION_NAME = "Daily-Mobility";
    const SPORT = Activity.SPORT_TRAINING;
    const SUB_SPORT = Activity.SUB_SPORT_FLEXIBILITY_TRAINING;

    var mSession;

    function initialize() {
        mSession = null;
    }

    function isRecording() {
        return mSession != null && mSession.isRecording();
    }

    function start() {
        if (mSession == null) {
            mSession = ActivityRecording.createSession({
                :name => SESSION_NAME,
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
