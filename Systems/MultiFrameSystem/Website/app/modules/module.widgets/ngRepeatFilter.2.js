var mod = angular.module('module.widgets');
mod.filter('range', function () {
    return function (input, total) {
        total = parseInt(total);

        for (var i = 0; i < total; i++) {
            input.push(i+1);
        }

        return input;
    };
});