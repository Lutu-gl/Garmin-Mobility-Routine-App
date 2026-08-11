using Toybox.Application;

// One routine, loaded from the JSON resource that tools/build_routine.py generates
// from its CSV. Each step is a dictionary { n, d, t, v } where t is 0 = time,
// 1 = reps and v is seconds (time) or a rep count (reps). Which routine is loaded is
// decided at start on the selection screen, so the resource is passed in; the title
// is the display name from the JSON, never hardcoded in the UI.
class RoutineModel {

    var title;
    var steps;
    var index;

    function initialize(resource) {
        var data = Application.loadResource(resource);
        title = data["title"];
        steps = data["steps"];
        index = 0;
    }

    function count() {
        return steps.size();
    }

    function current() {
        return steps[index];
    }

    function peekNext() {
        return hasNext() ? steps[index + 1] : null;
    }

    function hasNext() {
        return index < steps.size() - 1;
    }

    function hasPrev() {
        return index > 0;
    }

    function next() {
        if (hasNext()) { index += 1; return true; }
        return false;
    }

    function prev() {
        if (hasPrev()) { index -= 1; return true; }
        return false;
    }

    // Estimated total seconds: rep-based steps counted at 3 s per rep, plus the transition
    // countdown that opens every step. Keep in sync with tools/build_routine.py.
    function estimatedSeconds() {
        var total = steps.size() * 5;
        for (var i = 0; i < steps.size(); i += 1) {
            var s = steps[i];
            if (s["t"] == 0) { total += s["v"]; }
            else { total += s["v"] * 3; }
        }
        return total;
    }
}
