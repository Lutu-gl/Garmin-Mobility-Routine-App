using Toybox.Application;

// The routine, loaded from the JSON resource that tools/build_routine.py generates
// from routine.csv. Each step is a dictionary { n, d, t, v } where t is 0 = time,
// 1 = reps and v is seconds (time) or a rep count (reps).
class RoutineModel {

    var title;
    var steps;
    var index;

    function initialize() {
        var data = Application.loadResource(Rez.JsonData.routineData);
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

    function reset() {
        index = 0;
    }

    // Estimated total seconds; rep-based steps counted at 3 s per rep.
    function estimatedSeconds() {
        var total = 0;
        for (var i = 0; i < steps.size(); i += 1) {
            var s = steps[i];
            if (s["t"] == 0) { total += s["v"]; }
            else { total += s["v"] * 3; }
        }
        return total;
    }
}
