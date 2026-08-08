using Toybox.Application;
using Toybox.WatchUi;

// App entry point. Owns the routine model and the activity-recording session so
// both survive view changes and can be reached from any delegate via getApp().
class DailyMobilityApp extends Application.AppBase {

    var model;
    var sessionMgr;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        model = new RoutineModel();
        sessionMgr = new SessionManager();
    }

    // Never lose a running session when the app is closed mid-workout.
    function onStop(state) {
        if (sessionMgr != null) {
            sessionMgr.saveIfRecording();
        }
    }

    function getInitialView() {
        return [new StartView(model), new StartDelegate(model)];
    }
}

function getApp() {
    return Application.getApp();
}
