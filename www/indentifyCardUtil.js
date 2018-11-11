var stringToArrayBuffer = function(str) {
    var ret = new Uint8Array(str.length);
    for (var i = 0; i < str.length; i++) {
        ret[i] = str.charCodeAt(i);
    }
    // TODO would it be better to return Uint8Array?
    return ret.buffer;
};

var base64ToArrayBuffer = function(b64) {
    return stringToArrayBuffer(atob(b64));
};

var massageMessageNativeToJs = function(message) {
    if (message.CDVType == 'ArrayBuffer') {
        message = base64ToArrayBuffer(message.data);
    }
    return message;
}

// Cordova 3.6 doesn't unwrap ArrayBuffers in nested data structures
// https://github.com/apache/cordova-js/blob/94291706945c42fd47fa632ed30f5eb811080e95/src/ios/exec.js#L107-L122
var convertToNativeJS =  function(object) {
    Object.keys(object).forEach(function (key) {
        var value = object[key];
        object[key] = massageMessageNativeToJs(value);
        if (typeof(value) === 'object') {
            convertToNativeJS(value);
        }
    });
}
var exec = require('cordova/exec');

exports.getMessage = function (arg0, success, error) {
    var successWrapper = function(peripheral) {
        convertToNativeJS(peripheral);
        success(peripheral);
    };
    exec(successWrapper, error, 'indentifyCardUtil', 'getMessage', [arg0]);
};

exports.startScan = function (arg0, success, error) {
    var successWrapper = function(peripheral) {
        convertToNativeJS(peripheral);
        success(peripheral);
    };
    exec(successWrapper, error, 'indentifyCardUtil', 'startScan', [arg0]);
};

exports.connect = function (arg0, success, error) {
    var successWrapper = function(peripheral) {
        convertToNativeJS(peripheral);
        success(peripheral);
    };
    exec(successWrapper, error, 'indentifyCardUtil', 'connect', [arg0]);
};
