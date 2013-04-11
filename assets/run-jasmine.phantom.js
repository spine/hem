var system = require('system');

//
// Wait until the test condition is true or a timeout occurs.
//
// If timeout but condition still falsy: exit(1)
//

var waitFor = (function () {

    function getTime() {
        return (new Date).getTime();
    }

    return function (test, doIt, duration) {
        duration || (duration = 3000);

        var start = getTime(),
            finish = start + duration,
            int;

        function looop() {
            var time = getTime(),
                timeout = (time >= finish),
                condition = test();

            // No more time or condition fulfilled
            if (condition) {
                doIt(time - start);
                clearInterval(int);
            }

            // THEN, no moretime but condition unfulfilled
            if (timeout && !condition) {
                console.log("ERROR - Timeout for page condition.")
                phantom.exit(1);
            }
        }

        int = setInterval(looop, 1000 / 60);
    };
}());

if (system.args.length < 2 || system.args.length > 3) {
    console.log('Usage: run-jasmine.js URL [simple|colors]');
    phantom.exit(1);
}

var page = require('webpage').create();
page.onConsoleMessage = function(msg) {
    console.log(msg);
};

page.open(system.args[1], function (status) {
    if (status !== "success") {
        console.log("Cannot open URL");
        phantom.exit(1);
    }

    waitFor(function () {
        return page.evaluate(function () {
            return document.body.querySelector(".duration");
        });
    }, function (t) {
        var passed;
        passed = page.evaluate(function (formatter) {
            console.log(formatter)

            var formatColors = (function () {
                function indent(level) {
                    var ret = '';
                    for (var i = 0; i < level; i += 1) {
                        ret = ret + '  ';
                    }
                    return ret;
                }

                function tick(el) {
                    return $(el).is('.passed') ? '\033[32m✓\033[0m' : '\033[31m✖';
                }

                function desc(el, strong) {
                    strong || (strong = false);

                    var ret;
                    ret = $(el).find('> .description').text();
                    if (strong) {
                        ret = '\033[1m' + ret;
                    }

                    return ret;
                }

                return function (el, level, strong) {
                    return '\033[1m' + indent(level) + tick(el) + ' ' + desc(el, strong);
                };
            }());

            // TODO: select different formatters here
            // colors, totals, simple, default to colors
            //
            // create watchAndRun hem command, watch can return a single file, determine the suite from the file and run those
            var format = formatColors;

            function printSuites(root, level) {
                level || (level = 0);
                $(root).find('div.suite').each(function (i, el) {
                    console.log(format(el, level, true));
                    printSpecs(el, level + 1);
                    printSuites(el, level + 1);
                });
            }

            function printSpecs(root, level) {
                level || (level = 0);
                $(root).find('.specSummary').each(function (i, el) {
                    console.log(format(el, level));
                });
            }

            printSuites($('div.jasmine_reporter'));

            // TODO: print totals

            var fails = document.body.querySelectorAll('div.jasmine_reporter div.suite.failed');
            return fails.length === 0;
        }, system.args.length === 3 ? system.args[2] : undefined);

        phantom.exit(passed ? 0 : 1);
    });
});
