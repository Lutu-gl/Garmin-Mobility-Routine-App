using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Activity;
using Toybox.Attention;

// The main workout screen. Drives one 1-second timer that counts a time step down
// (auto-advancing at 0) or counts elapsed seconds up on a rep step. Handles pause,
// manual navigation and all the drawing described in the spec's screen layout.
class ExerciseView extends WatchUi.View {

    var mModel;
    var mTimer;
    var mRemaining;     // seconds left on a time step
    var mStepElapsed;   // seconds elapsed on the current step (rep up-counter)
    var mPaused;
    var mFinished;

    function initialize(model) {
        View.initialize();
        mModel = model;
        mTimer = null;
        mPaused = false;
        mFinished = false;
        loadStep();
    }

    // (Re)initialise per-step state for the current model index.
    function loadStep() {
        var s = mModel.current();
        mPaused = false;
        mStepElapsed = 0;
        mRemaining = (s["t"] == 0) ? s["v"] : 0;
        buzz(300);   // short vibration on every step change
    }

    // Timer only runs while the view is visible, to save battery (spec 3.3).
    function onShow() {
        if (!mFinished && mTimer == null) {
            mTimer = new Timer.Timer();
            mTimer.start(method(:onTick), 1000, true);
        }
    }

    function onHide() {
        stopTimer();
    }

    function stopTimer() {
        if (mTimer != null) {
            mTimer.stop();
            mTimer = null;
        }
    }

    function onTick() as Void {
        if (mPaused || mFinished) { return; }
        var s = mModel.current();
        if (s["t"] == 0) {
            mRemaining -= 1;
            mStepElapsed += 1;
            if (mRemaining > 0 && mRemaining <= 3) { tick(); }
            if (mRemaining <= 0) { advance(); return; }
        } else {
            mStepElapsed += 1;   // up-counter, no auto-advance on rep steps
        }
        WatchUi.requestUpdate();
    }

    // --- navigation, called from the delegate ---

    function onSelectPressed() {
        // Time: pause/resume. Reps: complete and move on.
        if (mModel.current()["t"] == 0) { togglePause(); }
        else { advance(); }
    }

    function togglePause() {
        mPaused = !mPaused;
        WatchUi.requestUpdate();
    }

    function goNext() {
        advance();
    }

    function goPrev() {
        if (mModel.prev()) {
            loadStep();
            WatchUi.requestUpdate();
        }
    }

    function advance() {
        if (mModel.next()) {
            loadStep();
            WatchUi.requestUpdate();
        } else {
            finish();
        }
    }

    function finish() {
        mFinished = true;
        stopTimer();
        buzz(600);
        WatchUi.switchToView(new SummaryView(), new SummaryDelegate(), WatchUi.SLIDE_LEFT);
    }

    // --- feedback helpers (guarded: not every device has Attention) ---

    function buzz(ms) {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(50, ms)]);
        }
    }

    function tick() {
        if (Attention has :vibrate) {
            Attention.vibrate([new Attention.VibeProfile(25, 80)]);
        }
        if (Attention has :playTone) {
            Attention.playTone(Attention.TONE_KEY);
        }
    }

    // --- drawing ---

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var s = mModel.current();

        // Status line: step counter (left) and heart rate (right).
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var status = (mModel.index + 1) + " / " + mModel.count();
        dc.drawText(w * 0.32, h * 0.15, Graphics.FONT_TINY, status,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w * 0.68, h * 0.15, Graphics.FONT_TINY, "♥ " + currentHr(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Exercise name, large.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.29, Graphics.FONT_MEDIUM, s["n"],
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Description, wrapped to at most 3 lines with an ellipsis on overflow.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawWrapped(dc, cx, h * 0.40, s["d"], Graphics.FONT_XTINY, w * 0.68, 3);

        // Central value: countdown or rep target.
        drawCentral(dc, cx, h * 0.63, s);

        // Overall routine progress bar.
        var prog = routineProgress();
        var barW = (w * 0.60).toNumber();
        var barH = 6;
        var barX = cx - barW / 2;
        var barY = (h * 0.80).toNumber();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, (barW * prog).toNumber(), barH);

        // Next-exercise preview.
        var nxt = mModel.peekNext();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (nxt != null) {
            dc.drawText(cx, h * 0.87, Graphics.FONT_XTINY, "next: " + nxt["n"],
                Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(cx, h * 0.87, Graphics.FONT_XTINY, "last exercise",
                Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function drawCentral(dc, cx, y, s) {
        if (s["t"] == 0) {
            var color = mPaused ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, Graphics.FONT_NUMBER_HOT, fmtTime(mRemaining),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            if (mPaused) {
                dc.drawText(cx, y + dc.getFontHeight(Graphics.FONT_NUMBER_HOT) / 2,
                    Graphics.FONT_XTINY, "‖ PAUSED",
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        } else {
            // Numeric font has no "x" glyph, so draw the count and " x" separately.
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var numStr = s["v"].toString();
            var numFont = Graphics.FONT_NUMBER_HOT;
            var timesStr = " ×";
            var timesFont = Graphics.FONT_MEDIUM;
            var numW = dc.getTextWidthInPixels(numStr, numFont);
            var timesW = dc.getTextWidthInPixels(timesStr, timesFont);
            var startX = cx - (numW + timesW) / 2;
            dc.drawText(startX, y, numFont, numStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.drawText(startX + numW, y, timesFont, timesStr,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function routineProgress() {
        var s = mModel.current();
        var frac = 0.0;
        if (s["t"] == 0 && s["v"] > 0) {
            frac = 1.0 - (mRemaining.toFloat() / s["v"]);
        }
        return (mModel.index + frac) / mModel.count();
    }

    function currentHr() {
        var info = Activity.getActivityInfo();
        if (info != null && info.currentHeartRate != null) {
            return info.currentHeartRate.toString();
        }
        return "--";
    }

    function fmtTime(secs) {
        if (secs < 0) { secs = 0; }
        var m = secs / 60;
        var sec = secs % 60;
        return m + ":" + (sec < 10 ? "0" + sec : "" + sec);
    }

    // --- word wrapping ---

    function drawWrapped(dc, cx, y, text, font, maxWidth, maxLines) {
        var lines = wrapLines(dc, text, font, maxWidth, maxLines);
        var lh = dc.getFontHeight(font);
        for (var i = 0; i < lines.size(); i += 1) {
            dc.drawText(cx, y + i * lh, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function wrapLines(dc, text, font, maxWidth, maxLines) {
        var words = splitWords(text);
        var lines = [];
        var cur = "";
        var i = 0;
        while (i < words.size() && lines.size() < maxLines - 1) {
            var word = words[i];
            var trial = cur.equals("") ? word : cur + " " + word;
            if (dc.getTextWidthInPixels(trial, font) <= maxWidth) {
                cur = trial;
                i += 1;
            } else {
                if (cur.equals("")) { cur = word; i += 1; }  // single long word
                lines.add(cur);
                cur = "";
            }
        }
        // Everything left goes on the final line, truncated with an ellipsis if needed.
        var rest = cur;
        while (i < words.size()) {
            rest = rest.equals("") ? words[i] : rest + " " + words[i];
            i += 1;
        }
        if (!rest.equals("")) {
            if (dc.getTextWidthInPixels(rest, font) > maxWidth) {
                rest = truncate(dc, rest, font, maxWidth);
            }
            lines.add(rest);
        }
        return lines;
    }

    function truncate(dc, text, font, maxWidth) {
        var ell = "…";
        var t = text;
        while (t.length() > 0 && dc.getTextWidthInPixels(t + ell, font) > maxWidth) {
            t = t.substring(0, t.length() - 1);
        }
        return t + ell;
    }

    function splitWords(text) {
        var words = [];
        var cur = "";
        var chars = text.toCharArray();
        for (var i = 0; i < chars.size(); i += 1) {
            if (chars[i] == ' ') {
                if (!cur.equals("")) { words.add(cur); cur = ""; }
            } else {
                cur += chars[i].toString();
            }
        }
        if (!cur.equals("")) { words.add(cur); }
        return words;
    }
}
