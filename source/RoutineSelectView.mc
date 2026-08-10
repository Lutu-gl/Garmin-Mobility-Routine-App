using Toybox.Application;
using Toybox.Lang;
using Toybox.WatchUi;
using Toybox.Graphics;

// Start screen: pick the routine before anything is recorded. Name, exercise count and
// estimated duration are read from the JSON resources, so this screen never has to be
// touched when a routine changes.
class RoutineSelectView extends WatchUi.View {

    const LAST_ROUTINE_KEY = "lastRoutine";
    const MARKER_W = 10;        // width of the selection triangle
    const MARKER_GAP = 8;

    var mEntries;
    var mTitles;
    var mCounts;
    var mSeconds;
    var mIndex;

    function initialize() {
        View.initialize();
        mEntries = RoutineCatalog.all();
        var n = mEntries.size();
        mTitles = new [n];
        mCounts = new [n];
        mSeconds = new [n];

        // Read the headline figures once and let the step lists go again: only the
        // routine that actually gets picked stays in memory during the workout.
        for (var i = 0; i < n; i += 1) {
            var m = new RoutineModel(mEntries[i][:res]);
            mTitles[i] = m.title;
            mCounts[i] = m.count();
            mSeconds[i] = m.estimatedSeconds();
            m = null;
        }

        mIndex = lastChoice(n);
    }

    // Preselect what was run last; the mobility routine otherwise, which is what five
    // days out of seven are.
    function lastChoice(n) {
        var v = Application.Storage.getValue(LAST_ROUTINE_KEY);
        if (v instanceof Lang.Number && v >= 0 && v < n) {
            return v;
        }
        return RoutineCatalog.MOBILITY;
    }

    // --- input, called from the delegate ---

    function move(delta) {
        var n = mEntries.size();
        mIndex = (mIndex + delta + n) % n;
        WatchUi.requestUpdate();
    }

    // Start recording under the chosen routine's name and hand over to the workout.
    function confirm() {
        var entry = mEntries[mIndex];
        Application.Storage.setValue(LAST_ROUTINE_KEY, mIndex);

        var app = getApp();
        app.model = new RoutineModel(entry[:res]);
        app.sessionMgr.start(entry[:session]);

        var view = new ExerciseView(app.model);
        WatchUi.pushView(view, new ExerciseDelegate(app.model, view), WatchUi.SLIDE_LEFT);
    }

    // --- drawing ---

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var maxW = w * 0.70;

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.20, Graphics.FONT_XTINY,
            Application.loadResource(Rez.Strings.AppName),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // One font for all entries, big enough to read and small enough for the longest
        // name to fit next to the marker.
        var font = fitFont(dc, maxW - MARKER_W - MARKER_GAP);
        var labelX = cx - textBlockWidth(dc, font) / 2 + MARKER_W + MARKER_GAP;
        var lineH = dc.getFontHeight(font) + 6;
        var firstY = h * 0.48 - (mEntries.size() - 1) * lineH / 2;

        for (var i = 0; i < mEntries.size(); i += 1) {
            var y = firstY + i * lineH;
            var selected = (i == mIndex);
            if (selected) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                drawMarker(dc, labelX - MARKER_GAP - MARKER_W, y);
            } else {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(labelX, y, font, mTitles[i],
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Figures of the highlighted routine.
        var mins = (mSeconds[mIndex] + 30) / 60;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.76, Graphics.FONT_XTINY,
            mins + " min · " + mCounts[mIndex] + " Übungen",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Filled triangle instead of a glyph, so it cannot fall back to a missing character.
    function drawMarker(dc, x, cy) {
        dc.fillPolygon([[x, cy - 7], [x, cy + 7], [x + MARKER_W, cy]]);
    }

    function textBlockWidth(dc, font) {
        return widestLabel(dc, font) + MARKER_W + MARKER_GAP;
    }

    function widestLabel(dc, font) {
        var widest = 0;
        for (var i = 0; i < mTitles.size(); i += 1) {
            var wpx = dc.getTextWidthInPixels(mTitles[i], font);
            if (wpx > widest) { widest = wpx; }
        }
        return widest;
    }

    // Largest font whose longest label still fits, else the smallest one.
    function fitFont(dc, maxWidth) {
        var fonts = [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY,
                     Graphics.FONT_XTINY];
        for (var i = 0; i < fonts.size(); i += 1) {
            if (widestLabel(dc, fonts[i]) <= maxWidth) { return fonts[i]; }
        }
        return fonts[fonts.size() - 1];
    }
}

// UP / DOWN move the selection, START confirms, BACK leaves the app.
class RoutineSelectDelegate extends WatchUi.BehaviorDelegate {

    var mView;

    function initialize(view) {
        BehaviorDelegate.initialize();
        mView = view;
    }

    function onNextPage() {
        mView.move(1);
        return true;
    }

    function onPreviousPage() {
        mView.move(-1);
        return true;
    }

    function onSelect() {
        mView.confirm();
        return true;
    }
}
