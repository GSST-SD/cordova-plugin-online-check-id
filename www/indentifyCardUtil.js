var exec = require('cordova/exec');

exports.getMessage = function (arg0, success, error) {
    exec(success, error, 'indentifyCardUtil', 'getMessage', [arg0]);
};


exports.startScan = function (arg0, success, error) {
    exec(success, error, 'indentifyCardUtil', 'startScan', [arg0]);
};


exports.connect = function (arg0, success, error) {
    exec(success, error, 'indentifyCardUtil', 'startScan', [arg0]);
};
