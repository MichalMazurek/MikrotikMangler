var express = require('express.io');
var path = require('path');
var favicon = require('serve-favicon');
var logger = require('morgan');
var cookieParser = require('cookie-parser');
var bodyParser = require('body-parser');

var routes = require('./routes/index');
var browserify = require("browserify-middleware");
var coffeeify = require("coffeeify");

browserify.settings('extensions', ['.coffee'])
browserify.settings('transform', [coffeeify])
browserify.settings('grep', /\.coffee$|\.js$/)

var lessMiddleware = require("less-middleware")
var app = express();

// view engine setup
app.set('views', path.join(__dirname, 'views'));
app.set('view engine', 'jade');
// uncomment after placing your favicon in /public
//app.use(favicon(path.join(__dirname, 'public', 'favicon.ico')));
app.use(logger('dev'));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));
app.use(cookieParser());

var users = require('./routes/users');
var apiv1 = require("./routes/apiv1")
app.use('/', routes);
app.use("/api/v1/", apiv1);

app.http().io()

app.io.route('/api/v1/channel/subscribe', function(req) {
  req.io.join("monitoring")
})

var redis = require("redis")

var redis_client = redis.createClient()

redis_client.on("message", function(channel, message) {
  app.io.room("monitoring").broadcast("monitoring", message)
})

redis_client.subscribe("monitoring")


if (process.env.NODE_ENV === 'dev') {

  app.use("/js/app.js", browserify("./public/javascripts/index.coffee"))
  app.use(lessMiddleware(__dirname + "/public"));
// development error handler
// will print stacktrace

  app.use(function(err, req, res, next) {
    res.status(err.status || 500);
    res.render('error', {
      message: err.message,
      error: err
    });
  });
}

// basic static
app.use(express.static(path.join(__dirname, 'public')));
app.use(express.static(path.join(__dirname, 'node_modules', 'flat-ui')));
app.use(express.static(path.join(__dirname, 'node_modules', 'font-awesome')));

// catch 404 and forward to error handler
app.use(function(req, res, next) {
  var err = new Error('Not Found');
  err.status = 404;
  next(err);
});

// error handlers
// production error handler
// no stacktraces leaked to user
app.use(function(err, req, res, next) {
  res.status(err.status || 500);
  res.render('error', {
    message: err.message,
    error: {}
  });
});


module.exports = app;
