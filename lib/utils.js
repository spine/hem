(function() {
  var flatten;

  exports.flatten = flatten = function(array, results) {
    var item, _i, _len;
    if (results == null) results = [];
    for (_i = 0, _len = array.length; _i < _len; _i++) {
      item = array[_i];
      if (Array.isArray(item)) {
        flatten(item, results);
      } else {
        results.push(item);
      }
    }
    return results;
  };

  exports.toArray = function(value) {
    if (value == null) value = [];
    if (Array.isArray(value)) {
      return value;
    } else {
      return [value];
    }
  };

}).call(this);
