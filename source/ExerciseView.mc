using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Timer;
using Toybox.Activity;
using Toybox.Attention;

// The main workout screen. One 100 ms timer drives everything: the 1-second countdown
// logic (derived by counting ticks) and the smooth horizontal scrolling of any line that
// is too long to fit. A time step counts down and auto-advances at 0; a rep step counts
// elapsed seconds up. Layout is measured and stacked top to bottom so nothing overlaps or
// runs off the round display.
class ExerciseView extends WatchUi.View {

    const TICK_MS = 100;        // timer period
    const SECOND_TICKS = 10;    // 10 ticks == 1 second
    const SCROLL_SPEED = 3;     // pixels advanced per tick for the marquee
    const SCROLL_GAP = 34;      // gap between the end and the wrapped-around start

    var mModel;
    var mTimer;
    var mRemaining;     // seconds left on a time step
    var mStepElapsed;   // seconds elapsed on the current step (rep up-counter)
    var mPaused;
    var mFinished;
    var mTicks;         // total timer ticks since the current step started
    var mScrollPx;      // accumulated marquee offset in pixels
    var mNeedsScroll;   // true when some visible line is being scrolled

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
        mTicks = 0;
        mScrollPx = 0;
        mNeedsScroll = false;
        mRemaining = (s["t"] == 0) ? s["v"] : 0;
        buzz(300);   // short vibration on every step change
    }

    // Timer only runs while the view is visible, to save battery (spec 3.3).
    function onShow() {
        if (!mFinished && mTimer == null) {
            mTimer = new Timer.Timer();
            mTimer.start(method(:onTick), TICK_MS, true);
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
        if (mFinished) { return; }
        mTicks += 1;
        var secondBoundary = (mTicks % SECOND_TICKS == 0);

        if (secondBoundary && !mPaused) {
            var s = mModel.current();
            if (s["t"] == 0) {
                mRemaining -= 1;
                mStepElapsed += 1;
                if (mRemaining > 0 && mRemaining <= 3) { tick(); }
                if (mRemaining <= 0) { advance(); return; }
            } else {
                mStepElapsed += 1;   // up-counter, no auto-advance on rep steps
            }
        }

        // Redraw every tick while scrolling (for smooth motion), otherwise once a second.
        if (mNeedsScroll) {
            mScrollPx += SCROLL_SPEED;
            WatchUi.requestUpdate();
        } else if (secondBoundary) {
            WatchUi.requestUpdate();
        }
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
        var midW = w * 0.66;    // safe text width across the middle of the round screen
        var edgeW = w * 0.54;   // tighter width near the narrow top/bottom
        var s = mModel.current();
        var scrolling = false;  // does any line need the marquee this frame?

        // Status row: step counter (left) and heart rate (right).
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var status = (mModel.index + 1) + " / " + mModel.count();
        dc.drawText(w * 0.31, h * 0.15, Graphics.FONT_TINY, status,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w * 0.69, h * 0.15, Graphics.FONT_TINY, "♥ " + currentHr(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Exercise name: pick the largest font that fits on one line; only wrap to two
        // lines if even the smallest font is too wide.
        var nameFont = fitFont(dc, s["n"],
            [Graphics.FONT_MEDIUM, Graphics.FONT_SMALL, Graphics.FONT_TINY], midW);
        var nameLines;
        if (dc.getTextWidthInPixels(s["n"], nameFont) <= midW) {
            nameLines = [s["n"]];
        } else {
            nameLines = wrapLines(dc, s["n"], nameFont, midW, 2);
        }
        var nameLh = dc.getFontHeight(nameFont);
        var nameTop = h * 0.21;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < nameLines.size(); i += 1) {
            dc.drawText(cx, nameTop + i * nameLh, nameFont, nameLines[i],
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        var nameBottom = nameTop + nameLines.size() * nameLh;

        // Description. Long text scrolls instead of being cut off with an ellipsis.
        // If the name already took two lines, the description gets a single scrolling
        // line; otherwise a static first line plus a scrolling remainder.
        var descFont = Graphics.FONT_XTINY;
        var descLh = dc.getFontHeight(descFont);
        var descTop = nameBottom + 6;
        var descLines;
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        if (nameLines.size() >= 2) {
            descLines = 1;
            if (drawScrollingLine(dc, cx, descTop + descLh / 2, s["d"], descFont, midW)) {
                scrolling = true;
            }
        } else {
            var parts = splitFirstLine(dc, s["d"], descFont, midW);
            descLines = parts[1].equals("") ? 1 : 2;
            dc.drawText(cx, descTop + descLh / 2, descFont, parts[0],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            if (!parts[1].equals("")) {
                if (drawScrollingLine(dc, cx, descTop + descLh + descLh / 2,
                        parts[1], descFont, midW)) {
                    scrolling = true;
                }
            }
        }
        var descBottom = descTop + descLines * descLh;

        // Progress bar near the bottom; the big value is centred in the gap above it.
        var barW = (w * 0.60).toNumber();
        var barH = 6;
        var barX = cx - barW / 2;
        var barY = (h * 0.82).toNumber();

        drawCentral(dc, cx, (descBottom + barY) / 2, barY - descBottom, s);

        var prog = routineProgress();
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, barW, barH);
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(barX, barY, (barW * prog).toNumber(), barH);

        // Bottom line: PAUSE while paused, otherwise the next-exercise preview (scrolls).
        var infoY = h * 0.90;
        if (mPaused) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, infoY, Graphics.FONT_XTINY, "PAUSE",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            var nxt = mModel.peekNext();
            var label = (nxt != null) ? "next: " + nxt["n"] : "last exercise";
            if (drawScrollingLine(dc, cx, infoY, label, Graphics.FONT_XTINY, edgeW)) {
                scrolling = true;
            }
        }

        mNeedsScroll = scrolling;
    }

    // Draws the countdown (time) or rep target, using the biggest numeric font that fits
    // the available vertical band so it never collides with the bar or the description.
    function drawCentral(dc, cx, y, bandH, s) {
        var numFont = (bandH >= dc.getFontHeight(Graphics.FONT_NUMBER_HOT))
            ? Graphics.FONT_NUMBER_HOT : Graphics.FONT_NUMBER_MEDIUM;
        if (s["t"] == 0) {
            var color = mPaused ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE;
            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, y, numFont, fmtTime(mRemaining),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        } else {
            // Numeric font has no "x" glyph, so draw the count and " x" separately.
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var numStr = s["v"].toString();
            var timesStr = " ×";
            var timesFont = Graphics.FONT_SMALL;
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

    // --- text fitting / scrolling helpers ---

    // Draws one line centred if it fits maxWidth, otherwise scrolls it horizontally within
    // a clip window (the marquee wraps around with a gap). Returns true when it scrolled.
    function drawScrollingLine(dc, cx, y, text, font, maxWidth) {
        var tw = dc.getTextWidthInPixels(text, font);
        if (tw <= maxWidth) {
            dc.drawText(cx, y, font, text,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return false;
        }
        var lh = dc.getFontHeight(font);
        var clipX = (cx - maxWidth / 2).toNumber();
        var clipY = (y - lh / 2).toNumber();
        var clipW = maxWidth.toNumber();
        dc.setClip(clipX, clipY, clipW, lh);
        var total = tw + SCROLL_GAP;
        var off = mScrollPx % total;
        var startX = clipX - off;
        dc.drawText(startX, y, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(startX + total, y, font, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.clearClip();
        return true;
    }

    // Largest font whose single-line width fits maxWidth, else the smallest given.
    function fitFont(dc, text, fonts, maxWidth) {
        for (var i = 0; i < fonts.size(); i += 1) {
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth) {
                return fonts[i];
            }
        }
        return fonts[fonts.size() - 1];
    }

    // Splits text into [firstLineThatFits, remainder] on word boundaries.
    function splitFirstLine(dc, text, font, maxWidth) {
        var words = splitWords(text);
        var cur = "";
        var i = 0;
        while (i < words.size()) {
            var trial = cur.equals("") ? words[i] : cur + " " + words[i];
            if (dc.getTextWidthInPixels(trial, font) <= maxWidth) {
                cur = trial;
                i += 1;
            } else {
                break;
            }
        }
        if (cur.equals("") && words.size() > 0) { cur = words[0]; i = 1; }  // long word
        var rest = "";
        while (i < words.size()) {
            rest = rest.equals("") ? words[i] : rest + " " + words[i];
            i += 1;
        }
        return [cur, rest];
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
