// Preferences.js
//
// Provides the set of known user preferences for Illuminator


(function() {

    var root = this,
        preferences = null;

    // put preferences in namespace of importing code
    if (typeof exports !== 'undefined') {
        preferences = exports;
    } else {
        preferences = root.preferences = {};
    }

    preferences.extensions = {};
    preferences.extensions.reduceTimeout = 10; // seconds

    preferences.automator = {};
    preferences.automator.onError = {};

}).call(this);
