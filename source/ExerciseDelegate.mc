using Toybox.WatchUi;
using Toybox.System;

// Button handling during a workout (Forerunner 255 Music, 5 buttons, no touch).
//   START (onSelect)      -> pause/resume a time step, or finish a rep step
//   DOWN  (onNextPage)    -> next exercise (also serves as "skip")
//   UP    (onPreviousPage)-> previous exercise
//   BACK  (onBack)        -> end menu: save / discard / cancel
// Long-press START is intentionally not used; DOWN is the skip action instead.
class ExerciseDelegate extends WatchUi.BehaviorDelegate {

    var mModel;
    var mView;

    function initialize(model, view) {
        BehaviorDelegate.initialize();
        mModel = model;
        mView = view;
    }

    function onSelect() {
        mView.onSelectPressed();
        return true;
    }

    function onNextPage() {
        mView.goNext();
        return true;
    }

    function onPreviousPage() {
        mView.goPrev();
        return true;
    }

    function onBack() {
        var menu = new WatchUi.Menu2({:title => "Finish workout?"});
        menu.addItem(new WatchUi.MenuItem("Save & Finish", null, :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard", null, :discard, null));
        menu.addItem(new WatchUi.MenuItem("Cancel", null, :cancel, null));
        WatchUi.pushView(menu, new EndMenuDelegate(), WatchUi.SLIDE_UP);
        return true;
    }
}

// Confirmation menu shown on BACK.
class EndMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :save) {
            getApp().sessionMgr.saveAndFinish();
            System.exit();
        } else if (id == :discard) {
            getApp().sessionMgr.discard();
            System.exit();
        } else {
            WatchUi.popView(WatchUi.SLIDE_DOWN);   // cancel
        }
    }

    function onBack() {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}
