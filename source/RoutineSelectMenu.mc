using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
using Toybox.WatchUi;

// Start screen: pick the routine before anything is recorded. Name, exercise count and
// estimated duration are read from the JSON resources, so this screen never has to be
// touched when a routine changes.
//
// This is a system menu rather than a drawn view because a short UP press does not reach
// an app's own root view on this watch — only DOWN would have worked. The system handles
// the scrolling here, so both buttons behave the way the rest of the watch does.
class RoutineSelectMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => Application.loadResource(Rez.Strings.AppName) });

        var entries = RoutineCatalog.all();
        for (var i = 0; i < entries.size(); i += 1) {
            // Read the figures, then let the step list go again: only the routine that
            // actually gets picked stays in memory during the workout.
            var m = new RoutineModel(entries[i][:res]);
            var mins = (m.estimatedSeconds() + 30) / 60;
            addItem(new WatchUi.MenuItem(
                m.title,
                mins + " min · " + m.count() + " Übungen",
                i,
                null));
            m = null;
        }

        setFocus(lastChoice(entries.size()));
    }

    // Preselect what was run last; the mobility routine otherwise, which is what five
    // days out of seven are.
    function lastChoice(n) {
        var v = Application.Storage.getValue(RoutineCatalog.LAST_KEY);
        if (v instanceof Lang.Number && v >= 0 && v < n) {
            return v;
        }
        return RoutineCatalog.MOBILITY;
    }
}

// START starts the highlighted routine, BACK leaves the app.
class RoutineSelectMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var index = item.getId();
        var entry = RoutineCatalog.all()[index];
        Application.Storage.setValue(RoutineCatalog.LAST_KEY, index);

        var app = getApp();
        app.model = new RoutineModel(entry[:res]);
        app.sessionMgr.start(entry[:session]);

        var view = new ExerciseView(app.model);
        WatchUi.pushView(view, new ExerciseDelegate(app.model, view), WatchUi.SLIDE_LEFT);
    }

    function onBack() {
        System.exit();
    }
}
