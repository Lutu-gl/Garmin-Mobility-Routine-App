using Toybox.WatchUi;
using Toybox.Graphics;

// Start screen: routine name, number of exercises, estimated total duration.
class StartView extends WatchUi.View {

    var mModel;

    function initialize(model) {
        View.initialize();
        mModel = model;
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.34, Graphics.FONT_MEDIUM, mModel.title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var mins = (mModel.estimatedSeconds() + 30) / 60;
        var sub = mModel.count() + " exercises   ~" + mins + " min";
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.50, Graphics.FONT_SMALL, sub,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.68, Graphics.FONT_XTINY, "START to begin",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// START begins the activity recording and opens the first exercise.
class StartDelegate extends WatchUi.BehaviorDelegate {

    var mModel;

    function initialize(model) {
        BehaviorDelegate.initialize();
        mModel = model;
    }

    function onSelect() {
        mModel.reset();
        getApp().sessionMgr.start();
        var view = new ExerciseView(mModel);
        WatchUi.pushView(view, new ExerciseDelegate(mModel, view), WatchUi.SLIDE_LEFT);
        return true;
    }
}
