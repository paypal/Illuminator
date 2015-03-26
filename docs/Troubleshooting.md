Troubleshooting ILLUMINATOR
===========================

Here are some common problems in Illuminator, and their fixes.  When diagnosing problems, it is imperative that you run Illuminator with the `--verbose` option.


Bridge Problems
---------------

### Messages about Ruby not working after a bridge call
```
2015-01-25 21:45:49 +0000 Warning: Ruby may not be working, try $ ruby /Users/you/project/illuminator/scripts/UIAutomationBridge.rb --callUID=Bridge_call_1 --selector=banana
2015-01-25 21:45:49 +0000 Error: Script threw an uncaught JavaScript error: Bridge got back an empty/blank string instead of JSON on line 71 of Bridge.js
2015-01-25 21:45:50 +0000 Stopped: Script was stopped by the user
```

Possible causes:
1. Ruby may be missing one of its dependencies.  Did you run `bundle install`?
2. You may not have defined the handler for the bridge selector you are using (in this case, `banana`) in your application.


Automator Problems
------------------

### `Failed assertion that '(some screen)' is active`

This is an indcation that the "screen is active" function that you supplied to `.onTarget()` in the `AppMap` returned `false`.  Several things may be to blame:
1. The screen you were expecting to be on for the next action in the test scenario did not appear
2. The screen you were expecting did appear, but your function was unable to detect it
3. Your function does not wait long enough for the screen to appear.  If you are using `.waitForChildExistence()`, consider increasing the timeout.
4. You are trying to wait for a transient element (like a progress dialog) and it's disappearing before Illuminator can find it.
5. A transient element (like a progress dialog) is taking longer than normal to disappear, and you ran into a timeout.  Consider using `.waitForChildSelect()` to detect the existence of the transient element and increase the overall timeout of your "screen is active" function.




Element or [Selector](Selectors.md) Problems
--------------------------------------------

### Unexpected numbers of elements from selector

```<Illuminator function>: expected 1 element from selector <selector>, received N```

If N is 0, this means that your criteria selector did not find any matching elements.  If you were using a criteria _array_ selector, at least one object failed to find a match.

If N is greater than 1, this means that you have used a "Criteria selector" that was ambiguous.  For example, if you searched for just a name but that name appeared for both a `UIATableCell` and a `UIAStaticText` inside that table cell.  You should make the selector more specific, expand your selector to a criteria _array_ selector to help establish the hierarchy you are looking for, or run a more targeted criteria selector search by starting it from an element deeper in the tree.
