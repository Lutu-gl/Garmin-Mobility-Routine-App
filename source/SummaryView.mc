using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Activity;
using Toybox.System;

// Shown after the last exercise: total time and average heart rate, then save.
class SummaryView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.24, Graphics.FONT_MEDIUM, "Done!",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var dur = "--";
        var avg = "--";
        var info = Activity.getActivityInfo();
        if (info != null) {
            if (info.timerTime != null) { dur = fmtDur(info.timerTime / 1000); }
            if (info.averageHeartRate != null) { avg = info.averageHeartRate.toString(); }
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.45, Graphics.FONT_SMALL, "Time   " + dur,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, h * 0.57, Graphics.FONT_SMALL, "♥ avg   " + avg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "START to save",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function fmtDur(secs) {
        var m = secs / 60;
        var sec = secs % 60;
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec);
    }
}

// Any key saves the activity and exits.
class SummaryDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() {
        save();
        return true;
    }

    function onBack() {
        save();
        return true;
    }

    function save() {
        getApp().sessionMgr.saveAndFinish();
        System.exit();
    }
}
